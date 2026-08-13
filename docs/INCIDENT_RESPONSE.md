# Incident Response Guide

## Severity levels

| Level | Definition | Example | Response time |
|---|---|---|---|
| SEV1 | Total outage — no orders can be placed at all | Backend down, DB unreachable | Immediately |
| SEV2 | Partial outage — core flow degraded but working | Automation stuck, SSE not delivering | < 1 hour |
| SEV3 | Non-critical — a feature broken, workaround exists | Earnings summary wrong, one queue backing up | < 1 day |

## First 5 minutes (any severity)

1. `curl https://api.daily.kg/api/ready` — which dependency is failing?
2. Check Grafana → Backend Overview — is it a traffic spike, an error
   spike, or a resource exhaustion (CPU/RAM/disk)?
3. Check Sentry (if `SENTRY_DSN` configured) for the actual stack trace of
   whatever's throwing.
4. Check `GET /api/settings/automation-errors` — is this an automation
   problem specifically (orders stuck) vs. the whole API being down?

## Backend won't respond at all (SEV1)

```bash
docker compose -f docker-compose.prod.yml ps backend   # is the container even running?
docker compose -f docker-compose.prod.yml logs --tail=100 backend
```

If it's crash-looping, the last log lines before each restart are the
crash reason (`app.js` logs a `fatal` line via pino before `process.exit(1)`
on startup failure). Common causes: bad `DATABASE_URL`, a migration that
failed, `JWT_SECRET` missing.

## Database unreachable (SEV1)

See `docs/DISASTER_RECOVERY.md` § PostgreSQL down. Short version: the
backend keeps running and serves cached/in-memory data where it can
(automation settings, earnings rates are cached in-process), but every
route that queries the DB starts returning 500s. `/api/ready` reports
`database.ok: false` immediately.

## Redis unreachable (SEV2, not SEV1)

The backend does **not** crash — `bus.js` and `queue.js` were built to
degrade, not fail hard, but degrade differently depending on when Redis
drops:

- If it was never configured (`REDIS_URL` unset): nothing changes, this
  isn't an incident.
- If it *was* connected and drops mid-flight: `bus.js`'s `pub`/`sub`
  clients emit `'error'` (logged, not thrown — see the `.on('error', ...)`
  handlers), but events stop propagating **between instances**. A single
  instance's own local listeners still fire (local-first `emit()`), so
  automation on that instance keeps working; only cross-instance SSE
  delivery and queue processing stop until Redis comes back. ioredis
  reconnects automatically by default.

Action: check Redis is actually up (`redis-cli -u $REDIS_URL ping`),
restart it if not, ioredis reconnects without a backend restart needed.

## Orders stuck / automation not progressing (SEV2)

See Runbook § "An order is stuck". Usually a downstream constraint
violation or a transient DB error that `sweep()` will retry — check
`automation_errors` first before assuming anything is broken.

## Traffic spike / suspected DDoS (SEV1 or SEV2 depending on impact)

1. Check nginx's rate-limit hit rate: `grep "limiting requests" /var/log/nginx/error.log | wc -l`
2. If it's a real attack (not a legitimate spike): enable Cloudflare "Under
   Attack Mode" if Cloudflare is in front (see `security/README.md`).
3. If nginx itself is overwhelmed: temporarily lower
   `limit_req_zone ... rate=` in `nginx/nginx.conf` and reload
   (`nginx -s reload`, no restart needed).

## Postmortem template (fill in after any SEV1/SEV2)

```
## Incident: <title>
Date/time (UTC):
Severity:
Duration:
Detected by: (alert / user report / manual check)

### Timeline

### Root cause

### What went well

### What to fix
- [ ] Immediate fix (already done?)
- [ ] Follow-up: prevent recurrence
- [ ] Follow-up: detect faster next time
```
