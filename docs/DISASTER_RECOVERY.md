# Disaster Recovery

## If the server crashes / host dies

**Impact**: total outage until a new instance starts.

**Recovery**:
- Render: auto-restarts the container; if the host itself dies, Render
  reschedules onto new infrastructure automatically (managed platform).
- Docker Compose on a VM: `restart: unless-stopped` on every service
  means Docker restarts crashed containers automatically. If the whole VM
  dies, there's no automatic host failover — this is the single biggest
  gap in the current setup (see `docs/SCALING.md` for when this needs to
  become multi-host).
- PM2: `autorestart: true`, `max_restarts: 10` in `ecosystem.config.js`
  handles process-level crashes on the same host.

**Data loss**: none — the crash doesn't touch Postgres/Redis, which are
separate processes/containers with their own persistence.

## If Redis goes down

**Impact**: SEV2, not SEV1. See `docs/INCIDENT_RESPONSE.md` for the
detailed behavior. In short: local automation keeps working on whichever
instance still has an event in memory; cross-instance SSE delivery and
BullMQ queue processing pause until Redis is back.

**Data loss**:
- Pub/sub messages in flight at the moment of the crash: lost (pub/sub is
  fire-and-forget by design, not a durable log — this is an accepted
  tradeoff, not a bug: durability for cross-instance coordination isn't
  worth the complexity here since automation.js's own `sweep()` (runs
  every 60s regardless of Redis) re-discovers any order that got missed).
- Queue jobs (notifications/history/earnings): **not lost** — BullMQ
  persists them in Redis's own AOF/RDB (see `redis-server --appendonly
  yes` in `docker-compose.prod.yml`). If Redis restarts with its data
  volume intact, queued-but-not-yet-processed jobs resume automatically.
  If the Redis *data volume itself* is lost (not just the process), those
  specific jobs are gone — the underlying order data in Postgres is
  unaffected, only the notification/history/earnings side-effects for
  whatever was queued at that exact moment.

**Recovery**: restart Redis. `ioredis` reconnects automatically
(`bus.js`/`queue.js` don't need a backend restart). If the data volume was
lost, nothing further to do — BullMQ queues start empty, new jobs enqueue
normally.

## If PostgreSQL is unreachable

**Impact**: SEV1 — every DB-backed route returns 500,
`/api/ready`'s `database.ok` flips to `false` immediately.

**Recovery**:
1. Managed Postgres (Supabase/RDS): check the provider's status page
   first — usually their problem, not yours, and they handle failover.
2. Self-hosted (`docker-compose.prod.yml`'s `postgres` service): check
   `docker compose logs postgres` for a crash reason (usually disk full
   or OOM). Restart: `docker compose -f docker-compose.prod.yml restart
   postgres`.
3. If the data volume is corrupted/lost: restore from the most recent
   backup — `scripts/restore.sh <backup-file> --force`. Data loss window
   = time since the last backup (daily by default, see
   `scripts/backup.sh` — worst case 24h of orders lost if backups are on
   the default daily cron and the volume is destroyed right before the
   next one).

**Preventing this**: this is exactly the argument for a managed Postgres
provider over the self-hosted `docker-compose.prod.yml` option in
production — point-in-time recovery (seconds of data loss, not a day) is
a checkbox on Supabase/RDS, not something this repo's backup script
attempts to reproduce.

## If the Queue (BullMQ) stops processing

**Impact**: SEV3 normally — notifications/history/earnings writes queue up
but nothing is lost (they're durable in Redis, see above), customers just
don't see notifications until it recovers. Escalates to SEV2 if the queue
backlog grows large enough to signal a stuck worker process rather than a
transient blip.

**Diagnosis**:
```bash
curl -H "Authorization: Bearer $ADMIN_TOKEN" https://api.daily.kg/api/ready
# checks.queue.queues.<name>.waiting climbing and .active staying at 0
# means workers aren't picking jobs up at all
```

**Recovery**:
```bash
docker compose -f docker-compose.prod.yml restart worker
# or, if running workers inline in the API process:
docker compose -f docker-compose.prod.yml restart backend
```

Jobs already in the queue are untouched by a worker restart — they
process as soon as a worker reconnects (BullMQ workers pull, they aren't
pushed to, so there's nothing to "resend").

## Recovery Time / Recovery Point objectives (honest, current state)

| Scenario | RTO (how long to recover) | RPO (how much data can be lost) |
|---|---|---|
| Backend process crash | Seconds (auto-restart) | None |
| Single host dies (Docker/PM2 setup) | Manual — provision a new host, no automatic failover | None (data is on separate Postgres/Redis) |
| Redis lost | Seconds (auto-reconnect) | Queued-but-unprocessed jobs at time of loss; Postgres data unaffected |
| Postgres lost (self-hosted) | Minutes to hours (manual restore) | Up to 24h (daily backup cadence) |
| Postgres lost (managed provider) | Minutes (provider failover) | Seconds (point-in-time recovery, provider-dependent) |

The self-hosted Postgres RPO/RTO numbers are the honest reason
`docs/DEPLOYMENT.md` recommends a managed database for real production
traffic, not the `postgres` service in `docker-compose.prod.yml`.
