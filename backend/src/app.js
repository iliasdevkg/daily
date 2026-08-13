require('dotenv').config();

const sentry = require('./sentry');
sentry.init(); // must run before anything else so it can catch startup errors too

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');

const pool = require('./config/database');
const migrations = require('./migrations');
const bus = require('./events/bus');
const queue = require('./queue');
const requestLogger = require('./middleware/requestLogger');
const metrics = require('./metrics');
const logger = require('./logger');

const app = express();

// Render/most PaaS terminate TLS in front of the app and forward over plain
// HTTP — without this, express-rate-limit and anything reading req.ip would
// see the proxy's address for every request instead of the real client.
app.set('trust proxy', 1);

app.use(requestLogger); // first: every request gets a request ID + structured log line, even a 400 from validation
app.use(metrics.httpMetricsMiddleware);
app.use(helmet());
app.use(compression());

// CORS: only the origins listed in ALLOWED_ORIGINS (comma-separated) may call
// this API. Requests with no Origin header (mobile apps, curl, server-to-server)
// are always allowed since they can't be spoofed by a malicious browser page.
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.length === 0 || allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    callback(new Error(`CORS: origin ${origin} is not allowed`));
  },
}));
app.use(express.json({ limit: '100kb' })); // an order/product payload never needs more; caps request-body DoS

// Health/ready/live and /metrics are registered before the rate limiter and
// stay exempt from it on purpose: Render's own uptime probe (render.yaml
// healthCheckPath) and any container orchestrator's liveness/readiness
// probes hit these on a fixed schedule regardless of anything else
// happening on the box, and Prometheus scrapes /metrics every few seconds
// — none of that should ever be able to make the platform think the
// service is down by tripping a limiter meant for the actual API surface.
app.get('/api/health', (req, res) => res.json({ status: 'OK', message: 'Сервер работает' }));
app.use('/api', require('./routes/health'));
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', metrics.registry.contentType);
  res.end(await metrics.registry.metrics());
});

// General API limiter — generous enough for normal browsing/polling, tight
// enough to blunt a scripted flood. /auth/* gets its own stricter limiter
// below, since credential-guessing needs a much lower ceiling than
// "load the product catalog".
app.use('/api', rateLimit({
  windowMs: 15 * 60 * 1000,
  // 1000, not a tighter number: Dashboard/Orders pages refetch on every SSE
  // 'order' event (see admin-web/src/pages/Dashboard.jsx), so one admin
  // watching a busy shift can legitimately fire many requests well within
  // real usage, not abuse.
  max: 1000,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Өтө көп суроо-талап. Бир аз убакыттан кийин кайталаңыз.' },
}));

// Brute-force protection for login/register specifically.
app.use('/api/auth', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Өтө көп аракет. 15 мүнөттөн кийин кайра аракет кылыңыз.' },
}));

// API routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/products', require('./routes/products'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/users', require('./routes/users'));
app.use('/api/categories', require('./routes/categories'));
app.use('/api/events', require('./routes/events')); // SSE: real-time order/notification/user updates
app.use('/api/settings', require('./routes/settings'));
app.use('/api/notifications', require('./routes/notifications'));
app.use('/api/earnings', require('./routes/earnings'));
app.use('/api/addresses', require('./routes/addresses'));
app.use('/api/favorites', require('./routes/favorites'));

// Last: catches anything that escaped every route's own try/catch and
// reports it to Sentry before falling back to a generic JSON error.
app.use(sentry.errorHandler);

const PORT = process.env.PORT || 3001;
const SHUTDOWN_TIMEOUT_MS = 10000;
let server;

// Schema first (migrations.js — single source of truth for everything
// beyond init.sql's initial tables), then the event bus connects to Redis
// (if configured) so every module started after this point can publish
// across instances, then each feature module subscribes.
//
// Sequential on purpose: automation.js/history.js/notifications.js/
// earnings.js used to each run their own CREATE TABLE at startup, and
// running those concurrently reliably produced Postgres "deadlock
// detected" on overlapping DDL — see migrations.js.
(async () => {
  try {
    await migrations.run();
    bus.connect(); // no-op if REDIS_URL isn't set
    await require('./automation').start();
    await require('./history').start();
    await require('./notifications').start();
    await require('./earnings').start();
    require('./email').start();
  } catch (err) {
    logger.fatal({ err }, 'Startup error');
    process.exit(1); // fail loudly — a half-started server (e.g. missing table) is worse than none
  }

  server = app.listen(PORT, () => {
    logger.info(
      { port: PORT, allowedOrigins: allowedOrigins.length ? allowedOrigins : 'same-origin only' },
      `Backend API: http://localhost:${PORT}`
    );
  });
})();

// Graceful shutdown: stop accepting new connections, let in-flight requests
// finish, then close the DB pool, Redis connections and queue workers —
// instead of Render/PM2/Kubernetes's SIGTERM killing everything mid-request
// on every deploy, restart, or rolling update.
function shutdown(signal) {
  logger.info({ signal }, 'Shutting down gracefully');
  if (!server) return process.exit(0);
  server.close(async () => {
    try {
      await queue.shutdown();
      await bus.disconnect();
      await pool.end();
    } catch (err) {
      logger.error({ err }, 'Error during shutdown');
    } finally {
      process.exit(0);
    }
  });
  // Don't hang forever if some connection never closes.
  setTimeout(() => process.exit(1), SHUTDOWN_TIMEOUT_MS).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
