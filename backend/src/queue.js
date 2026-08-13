// Background job queue for notifications/history/earnings — the
// side-effects of an order event that don't need to block the request
// that triggered them and benefit from retry-on-failure.
//
// Same graceful-fallback shape as events/bus.js: with REDIS_URL set, every
// enqueue() goes through a real BullMQ Queue (retry, exponential backoff,
// a dead-letter queue for exhausted jobs, idempotent via a deterministic
// jobId). Without it, enqueue() just calls the processor directly and
// synchronously — local dev without Redis keeps working exactly like
// before this queue system existed, no code at the call sites changes
// either way.
//
// automation.js's own core rules (auto-confirm, auto-assign, auto-complete)
// deliberately stay OFF this queue and react to bus events directly: they
// guard correctness with pg_advisory_xact_lock and need to feel instant to
// whoever's watching an order move through its stages — queueing them
// would add latency for no benefit and complicate the locking story for
// no reason.
const logger = require('./logger');
const metrics = require('./metrics');

const REDIS_URL = process.env.REDIS_URL;
const DEFAULT_ATTEMPTS = 5;
const BACKOFF_BASE_MS = 2000;

const queues = new Map();   // name -> BullMQ Queue (redis mode only)
const workers = new Map();  // name -> BullMQ Worker (redis mode only)
const localHandlers = new Map(); // name -> processor fn (no-redis mode only)
let deadLetterQueue = null;
let connection = null;

function enabled() {
  return !!REDIS_URL;
}

function getConnection() {
  if (!connection) {
    const Redis = require('ioredis');
    // BullMQ requires this exact option — without it, ioredis gives up on
    // a connection blip instead of letting BullMQ's own retry take over.
    connection = new Redis(REDIS_URL, { maxRetriesPerRequest: null });
    connection.on('error', (err) => logger.error({ err }, 'Redis (queue) connection error'));
  }
  return connection;
}

function getDeadLetterQueue() {
  if (!deadLetterQueue) {
    const { Queue } = require('bullmq');
    deadLetterQueue = new Queue('dead-letter', { connection: getConnection() });
  }
  return deadLetterQueue;
}

// Register how a named queue's jobs get processed. Call once per queue at
// startup, before anything enqueue()s to it.
function registerWorker(name, processor, opts = {}) {
  if (!enabled()) {
    localHandlers.set(name, processor);
    return;
  }
  const { Worker } = require('bullmq');
  const worker = new Worker(
    name,
    async (job) => {
      try {
        const result = await processor(job.data);
        metrics.queueJobsTotal.inc({ queue: name, outcome: 'completed' });
        return result;
      } catch (err) {
        logger.error({ err, queue: name, jobId: job.id, attempt: job.attemptsMade }, 'Queue job failed');
        throw err; // BullMQ handles retry/backoff based on the queue's job options
      }
    },
    { connection: getConnection(), concurrency: opts.concurrency || 5 }
  );

  worker.on('failed', async (job, err) => {
    if (!job) return;
    metrics.queueJobsTotal.inc({ queue: name, outcome: 'failed' });
    if (job.attemptsMade >= (job.opts.attempts || DEFAULT_ATTEMPTS)) {
      // Exhausted every retry — move it somewhere a human can see it
      // instead of it silently vanishing, same intent as
      // automation.js's automation_errors table.
      metrics.queueJobsTotal.inc({ queue: name, outcome: 'dead_letter' });
      await getDeadLetterQueue().add('dead', {
        originalQueue: name,
        jobName: job.name,
        data: job.data,
        error: err.message,
        failedAt: new Date().toISOString(),
      });
      logger.error({ queue: name, jobId: job.id }, 'Job moved to dead-letter queue after exhausting retries');
    }
  });

  workers.set(name, worker);
}

function getQueue(name) {
  if (!queues.has(name)) {
    const { Queue } = require('bullmq');
    queues.set(name, new Queue(name, { connection: getConnection() }));
  }
  return queues.get(name);
}

// jobKey should be deterministic (e.g. `${orderId}_${action}`) — BullMQ
// treats two adds with the same jobId as one job while the first is still
// pending/active, which is what makes this idempotent against the same
// order event accidentally being published twice (see bus.js's
// self-echo guard, which already prevents that at the source, but this is
// a second, independent layer rather than relying on just one).
//
// BullMQ hard-rejects any ':' in a custom job ID (its own internal Redis
// key-namespace separator) — sanitized here as a last line of defense
// regardless of what any call site passes, since this exact bug (an
// action string like 'status:confirmed' reaching a raw jobId) crashed the
// whole process the first time it was hit in testing. Call sites also
// sanitize their own keys; this is defense in depth, not a substitute.
async function enqueue(queueName, rawJobKey, data) {
  const jobKey = String(rawJobKey).replace(/:/g, '_');
  if (!enabled()) {
    const handler = localHandlers.get(queueName);
    if (!handler) return logger.warn({ queueName }, 'No local handler registered for queue');
    // No Redis means no retry infrastructure — best effort, log and move
    // on rather than letting a rejected promise become an unhandled
    // rejection in the caller (bus.emit doesn't await its listeners).
    try {
      return await handler(data);
    } catch (err) {
      metrics.queueJobsTotal.inc({ queue: queueName, outcome: 'failed' });
      logger.error({ err, queueName, jobKey }, 'Local (no-Redis) job failed, not retried');
    }
    return;
  }
  const queue = getQueue(queueName);
  return queue.add(jobKey, data, {
    jobId: jobKey,
    attempts: DEFAULT_ATTEMPTS,
    backoff: { type: 'exponential', delay: BACKOFF_BASE_MS },
    removeOnComplete: { age: 24 * 3600, count: 1000 },
    removeOnFail: false, // keep failed jobs visible until the dead-letter handoff reads them
  });
}

async function getCounts() {
  if (!enabled()) return { mode: 'local', queues: {} };
  const names = [...queues.keys()];
  const counts = {};
  for (const name of names) {
    counts[name] = await queues.get(name).getJobCounts('waiting', 'active', 'completed', 'failed', 'delayed');
  }
  const dlq = deadLetterQueue ? await deadLetterQueue.getJobCounts('waiting') : { waiting: 0 };
  return { mode: 'redis', queues: counts, deadLetter: dlq.waiting };
}

async function shutdown() {
  for (const worker of workers.values()) await worker.close();
  for (const queue of queues.values()) await queue.close();
  if (deadLetterQueue) await deadLetterQueue.close();
  if (connection) await connection.quit().catch(() => {});
}

module.exports = { enabled, registerWorker, enqueue, getCounts, shutdown };
