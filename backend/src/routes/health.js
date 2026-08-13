const router = require('express').Router();
const os = require('os');
const fs = require('fs');
const pool = require('../config/database');
const bus = require('../events/bus');
const queue = require('../queue');

// GET /api/live — is the process itself alive and able to respond at all?
// No dependency checks on purpose: a Kubernetes liveness probe failing
// restarts the container, so this must only fail when restarting would
// actually help (the process is deadlocked/wedged), never because a
// downstream dependency (DB, Redis) is having a bad moment — that's what
// /ready is for, and it's allowed to fail without triggering a restart.
router.get('/live', (req, res) => {
  res.json({ status: 'alive', pid: process.pid, uptimeSec: Math.round(process.uptime()) });
});

// GET /api/ready — can this instance actually serve traffic right now?
// Checked by a load balancer/orchestrator before routing requests here,
// and safe to fail (503) without anything restarting — the instance just
// gets skipped until it reports healthy again.
router.get('/ready', async (req, res) => {
  const checks = {};
  let allOk = true;

  // Database
  try {
    const start = Date.now();
    await pool.query('SELECT 1');
    checks.database = { ok: true, latencyMs: Date.now() - start };
  } catch (err) {
    checks.database = { ok: false, error: err.message };
    allOk = false;
  }

  // Redis (event bus + queue) — only checked if actually configured; a
  // deployment that never opted into Redis shouldn't be marked unready
  // for a dependency it doesn't use.
  if (process.env.REDIS_URL) {
    checks.redis = { ok: bus.redisEnabled, mode: 'pub/sub' };
    if (!bus.redisEnabled) allOk = false;
  }

  // Queue (BullMQ) — same conditional logic as Redis above, since it's
  // the same Redis instance backing both.
  if (queue.enabled()) {
    try {
      checks.queue = { ok: true, ...(await queue.getCounts()) };
    } catch (err) {
      checks.queue = { ok: false, error: err.message };
      allOk = false;
    }
  }

  // Disk — warn rather than fail: this repo's own dev machine hit 96%
  // full earlier and it degraded everything (see project history), so
  // surfacing it here before it becomes an outage is the point.
  try {
    const stat = fs.statfsSync ? fs.statfsSync('/') : null;
    if (stat) {
      const freeRatio = stat.bfree / stat.blocks;
      checks.disk = { ok: freeRatio > 0.05, freePercent: Math.round(freeRatio * 100) };
      if (freeRatio <= 0.05) allOk = false;
    }
  } catch {
    checks.disk = { ok: true, note: 'statfs unavailable on this platform' };
  }

  // Memory
  const freeMemRatio = os.freemem() / os.totalmem();
  checks.memory = { ok: freeMemRatio > 0.05, freePercent: Math.round(freeMemRatio * 100) };
  if (freeMemRatio <= 0.05) allOk = false;

  res.status(allOk ? 200 : 503).json({ status: allOk ? 'ready' : 'not_ready', checks });
});

module.exports = router;
