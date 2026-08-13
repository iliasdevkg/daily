const { EventEmitter } = require('events');
const crypto = require('crypto');

// Distributed pub/sub. Same public shape as a plain Node EventEmitter
// (.on/.off/.emit) so every existing consumer (automation.js, history.js,
// notifications.js, earnings.js, routes/events.js) needed zero changes —
// this file is the only thing that changed to make horizontal scaling
// possible.
//
// Local-only mode (no REDIS_URL): behaves exactly like the old bus.js —
// one process, emit() dispatches straight to local listeners. This is the
// default and what local dev still uses.
//
// Distributed mode (REDIS_URL set): every emit() still dispatches locally
// immediately (no Redis round-trip latency for same-process listeners —
// e.g. automation.js reacting to an order this same instance just created),
// AND publishes to a Redis channel so every OTHER instance's listeners
// (its own automation.js, and SSE clients connected to it) see the event
// too. Each message is tagged with this process's instance ID so an
// instance never re-processes its own event a second time when its own
// publish echoes back through the subscription.
const CHANNEL = 'daily:bus';
const INSTANCE_ID = crypto.randomUUID();

class DistributedBus extends EventEmitter {
  constructor() {
    super();
    this.setMaxListeners(0);
    this.redisEnabled = false;
    this.pub = null;
    this.sub = null;
  }

  // Called once from app.js at startup, after env vars are loaded — kept
  // separate from the constructor so requiring this module never has a
  // side effect (tests, or any script requiring it, don't open a socket).
  connect() {
    if (!process.env.REDIS_URL || this.redisEnabled) return;
    const Redis = require('ioredis');
    this.pub = new Redis(process.env.REDIS_URL, { lazyConnect: false });
    this.sub = new Redis(process.env.REDIS_URL, { lazyConnect: false });

    this.pub.on('error', (err) => console.error('Redis pub error:', err.message));
    this.sub.on('error', (err) => console.error('Redis sub error:', err.message));

    this.sub.subscribe(CHANNEL, (err) => {
      if (err) return console.error('Redis subscribe error:', err.message);
      this.redisEnabled = true;
      console.log(`🔌 Event bus: Redis pub/sub active (instance ${INSTANCE_ID.slice(0, 8)})`);
    });

    this.sub.on('message', (channel, raw) => {
      if (channel !== CHANNEL) return;
      try {
        const { instanceId, event, args } = JSON.parse(raw);
        if (instanceId === INSTANCE_ID) return; // our own publish echoing back — already dispatched locally below
        super.emit(event, ...args);
      } catch (err) {
        console.error('Redis message parse error:', err.message);
      }
    });
  }

  async disconnect() {
    if (this.pub) await this.pub.quit().catch(() => {});
    if (this.sub) await this.sub.quit().catch(() => {});
  }

  emit(event, ...args) {
    super.emit(event, ...args); // always local-first: no Redis round-trip for same-process listeners
    if (this.redisEnabled) {
      this.pub.publish(CHANNEL, JSON.stringify({ instanceId: INSTANCE_ID, event, args }))
        .catch((err) => console.error('Redis publish error:', err.message));
    }
    return true;
  }
}

module.exports = new DistributedBus();
