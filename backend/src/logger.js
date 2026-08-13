const pino = require('pino');

// Structured JSON logging. In dev, pino-pretty would be nicer to read, but
// that's an extra dependency for a cosmetic difference — production is what
// actually needs JSON (for log aggregators to parse), and JSON is still
// perfectly readable via `| npx pino-pretty` locally without installing it.
const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  base: { service: 'daily-backend' },
  timestamp: pino.stdTimeFunctions.isoTime,
  formatters: {
    level(label) {
      return { level: label }; // "info" not the numeric level pino defaults to
    },
  },
});

module.exports = logger;
