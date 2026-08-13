// Error tracking — no-ops entirely if SENTRY_DSN isn't set, so local dev
// and any environment without a Sentry project configured behaves exactly
// as before. Requires an actual Sentry account/project to do anything;
// this file is the integration code, not the account signup.
const Sentry = require('@sentry/node');

let enabled = false;

function init() {
  if (!process.env.SENTRY_DSN) {
    console.log('Sentry: SENTRY_DSN эмес, өчүрүлгөн');
    return;
  }
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV || 'development',
    tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  });
  enabled = true;
  console.log('🛰️  Sentry error tracking күйдү');

  // Catches what try/catch blocks miss — a throw in a callback nobody
  // awaited, a rejected promise nobody attached .catch() to. Without this,
  // Node just logs "UnhandledPromiseRejection" to stdout and the failure
  // is invisible unless someone happens to be tailing logs at that moment.
  process.on('uncaughtException', (err) => {
    Sentry.captureException(err);
    console.error('Uncaught exception:', err);
  });
  process.on('unhandledRejection', (reason) => {
    Sentry.captureException(reason instanceof Error ? reason : new Error(String(reason)));
    console.error('Unhandled rejection:', reason);
  });
}

function captureException(err, context) {
  if (enabled) Sentry.captureException(err, context ? { extra: context } : undefined);
}

// Express 5 error-handling middleware — must be registered after all
// routes. Reports 5xx to Sentry, then falls through to the app's own
// generic JSON error response (each route already returns its own message;
// this only fires for something that escaped every route's try/catch).
function errorHandler(err, req, res, next) {
  captureException(err, { path: req.path, method: req.method, userId: req.user?.id });
  req.log?.error({ err }, 'Unhandled route error');
  if (res.headersSent) return next(err);
  res.status(500).json({ message: 'Ички сервер катасы' });
}

module.exports = { init, captureException, errorHandler, isEnabled: () => enabled };
