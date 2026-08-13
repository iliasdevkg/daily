require('dotenv').config();

// Dedicated worker process — no Express server, no HTTP surface at all.
// Runs the exact same queue workers app.js registers inline (BullMQ lets
// multiple Worker instances share one queue: jobs are distributed between
// them, never duplicated — that's the whole mechanism horizontal worker
// scaling relies on). Running this is optional: a single app.js instance
// already processes its own queues inline, which is enough until job
// volume genuinely needs dedicated capacity — see docker-compose.prod.yml,
// where this becomes its own `worker` service you can scale independently
// of the API (`docker compose up --scale worker=3`).
//
// Requires REDIS_URL — without it there's no queue for a separate worker
// to pull from (queue.js's local-mode fallback only makes sense inside the
// same process that emitted the event), so this refuses to start instead
// of silently doing nothing.
if (!process.env.REDIS_URL) {
  console.error('worker.js REDIS_URL талап кылат (жалгыз процесс режиминде app.js өзү иштерди иштетет)');
  process.exit(1);
}

const sentry = require('./sentry');
sentry.init();

const logger = require('./logger');
const pool = require('./config/database');
const migrations = require('./migrations');
const bus = require('./events/bus');
const queue = require('./queue');

(async () => {
  try {
    await migrations.run(); // idempotent — safe even if the API instance already ran it
    bus.connect();

    // Only the queue-consuming half of each module — not bus.on('order', ...)
    // trigger registration, which stays in app.js. A worker container reacts
    // to jobs already enqueued by an API instance; it doesn't itself decide
    // when a new job should exist.
    const { processNotification } = require('./notifications').__internals;
    const { processHistoryEntry } = require('./history').__internals;
    const { processPayout } = require('./earnings').__internals;
    const { processEmail } = require('./email').__internals;

    queue.registerWorker('notifications', processNotification);
    queue.registerWorker('history', processHistoryEntry);
    queue.registerWorker('earnings', processPayout);
    queue.registerWorker('email', processEmail);

    logger.info('👷 Worker process баштады — notifications/history/earnings/email queues угулууда');
  } catch (err) {
    logger.fatal({ err }, 'Worker startup error');
    process.exit(1);
  }
})();

function shutdown(signal) {
  logger.info({ signal }, 'Worker shutting down gracefully');
  Promise.resolve()
    .then(() => queue.shutdown())
    .then(() => bus.disconnect())
    .then(() => pool.end())
    .catch((err) => logger.error({ err }, 'Error during worker shutdown'))
    .finally(() => process.exit(0));
  setTimeout(() => process.exit(1), 10000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
