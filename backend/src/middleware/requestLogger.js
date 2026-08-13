const pinoHttp = require('pino-http');
const crypto = require('crypto');
const logger = require('../logger');

// One structured JSON line per request, with everything Stage 7 asked for:
// request ID, user ID, role, duration, status code, IP, route, level, and
// (via pino's error serializer) the stack on 5xx. req.user is set by
// middleware/auth.js, which runs after this in the chain but before the
// route handler — by the time the response finishes (when these custom
// props are read), it's populated for any authenticated request.
module.exports = pinoHttp({
  logger,
  genReqId: (req) => req.headers['x-request-id'] || crypto.randomUUID(),
  customProps: (req) => ({
    userId: req.user?.id ?? null,
    role: req.user?.role ?? null,
  }),
  customLogLevel: (req, res, err) => {
    if (err || res.statusCode >= 500) return 'error';
    if (res.statusCode >= 400) return 'warn';
    return 'info';
  },
  // Health checks fire every few seconds from Render's probe and any
  // container orchestrator — logging each one at 'info' would drown out
  // everything else within hours.
  autoLogging: {
    ignore: (req) => req.url === '/api/health' || req.url === '/api/ready' || req.url === '/api/live',
  },
  customSuccessMessage: (req, res) => `${req.method} ${req.url} ${res.statusCode}`,
  customErrorMessage: (req, res, err) => `${req.method} ${req.url} ${res.statusCode} — ${err.message}`,
});
