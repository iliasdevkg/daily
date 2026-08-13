# Daily — Production Infrastructure

This file is the entry point for everything added in the infrastructure
hardening pass (Redis, queues, Docker, monitoring, CI/CD). For the
application itself, see the root `README.md`; for the code-level security/
correctness hardening that came before this pass, see
`backend/PRODUCTION_HARDENING_REPORT.md`.

## What's here

| Area | Where |
|---|---|
| Architecture, diagrams | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| How to deploy (3 options) | [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) |
| Day-2 operations | [`docs/RUNBOOK.md`](docs/RUNBOOK.md) |
| When something's on fire | [`docs/INCIDENT_RESPONSE.md`](docs/INCIDENT_RESPONSE.md) |
| "What if X dies" | [`docs/DISASTER_RECOVERY.md`](docs/DISASTER_RECOVERY.md) |
| When to add what (Redis Cluster, K8s, ...) | [`docs/SCALING.md`](docs/SCALING.md) |
| Dashboards, alerts, metrics reference | [`docs/MONITORING.md`](docs/MONITORING.md) |
| Security infra (WAF, secrets, TLS, fail2ban) | [`security/README.md`](security/README.md) |

## Quick start

```bash
# Local dev, full stack (Postgres + Redis + backend + admin-web + frontend):
docker compose up

# Production (see docs/DEPLOYMENT.md for the one-time setup steps first):
docker compose -f docker-compose.prod.yml up -d
```

## What changed, in one paragraph

The backend went from a single Node process with an in-memory
`EventEmitter` and no queue, logging, metrics, or container definitions,
to: Redis-backed pub/sub with a transparent single-instance fallback
(`backend/src/events/bus.js`), a BullMQ job queue with retry/backoff/
dead-letter for notifications/history/earnings/email
(`backend/src/queue.js`), structured JSON logging with request IDs
(`backend/src/logger.js`), Prometheus metrics (`backend/src/metrics.js`),
Sentry error tracking (`backend/src/sentry.js`), `/health` `/ready` `/live`
endpoints, a full Docker Compose stack (dev + prod, 11 services in prod:
backend×2, worker×2, postgres, redis, nginx, certbot, prometheus, grafana,
3 exporters), an nginx reverse proxy with TLS/SSE-proxying/rate-limiting,
a GitHub Actions CI/CD pipeline, and backup/restore scripts. None of it
requires the others — every piece degrades gracefully to its pre-existing
behavior when its dependency (Redis, in most cases) isn't configured.

## A bug this pass caught before it reached production

Enabling Redis mode and testing against a real instance (not just reading
the code) surfaced a crash: BullMQ rejects any `:` character in a custom
job ID, and this session's own job-key scheme used the action string
(`'status:confirmed'`) directly in one. Every single order confirmation
would have crashed the entire backend process the moment Redis was
enabled in production. Fixed in `queue.js` (a sanitizing layer on every
`enqueue()` call, defense-in-depth beyond the three call sites that also
sanitize their own keys) — full account in the git history and
`PRODUCTION_HARDENING_REPORT.md`. Left in this README specifically because
it's the clearest demonstration of why every claim in this pass was
tested against a running instance rather than asserted from reading code.
