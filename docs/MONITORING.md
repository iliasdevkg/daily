# Monitoring Guide

## Stack

Prometheus (scrapes `/metrics` every 15s) → Grafana (dashboards, reads
from Prometheus) → Alertmanager (not included — point
`monitoring/prometheus.yml`'s `alerting.alertmanagers` at one to make
`monitoring/alerts.yml` actually page someone; without it, alerts fire and
are visible in Prometheus's own UI but nothing notifies anyone).

## Access (docker-compose.prod.yml)

- Grafana: `http://<host>:3000` (bound to `127.0.0.1` by default — see the
  compose file comment; put it behind its own nginx server block + auth,
  or an SSH tunnel, before exposing it) — default login `admin` /
  `$GRAFANA_ADMIN_PASSWORD` (set in `.env`, no default value in code)
- Prometheus: `http://<host>:9090`, same `127.0.0.1`-only binding
- The pre-provisioned dashboard: Grafana → Dashboards → Daily → "Daily —
  Backend Overview" (`monitoring/grafana/dashboards/daily-overview.json`)

## What's on the dashboard

| Panel | Metric | What a problem looks like |
|---|---|---|
| HTTP request rate | `daily_http_requests_total` | Sudden spike = traffic surge or a retry storm; sudden drop to zero = the service is down or unreachable |
| p50/p95/p99 latency | `daily_http_request_duration_seconds` | p95 climbing while p50 stays flat = a subset of requests (often one slow query) is degrading, not everything |
| Orders created (rate) | `daily_orders_created_total` | The actual business metric — a real-world proxy for whether the system is doing its job at all |
| Automation actions | `daily_automation_actions_total{action}` | Should roughly track order creation rate; a gap means automation has stalled (cross-check `automation_errors`) |
| Automation errors | `daily_automation_errors_total{step}` | Any sustained non-zero rate here needs investigation — see Runbook |
| Queue jobs by outcome | `daily_queue_jobs_total{queue,outcome}` | `failed`/`dead_letter` outcomes climbing = a downstream problem (DB, external service) affecting that specific queue |
| Process memory/CPU | `daily_process_resident_memory_bytes`, `daily_process_cpu_seconds_total` | Memory climbing without ever coming back down between GCs = a leak; sustained high CPU = either real load or an inefficient hot path |
| Postgres connections | `pg_stat_activity_count` | Approaching `max_connections` = connection pool exhaustion incoming — see the DB audit in `PRODUCTION_HARDENING_REPORT.md` |
| Host CPU/memory/disk | node-exporter metrics | The exact "machine is critically low on disk/memory" condition that caused a real outage during this project's own development (see `docs/DISASTER_RECOVERY.md`) — this panel exists specifically because of that incident |

## Alert routing (once Alertmanager is wired up)

`monitoring/alerts.yml` groups: `daily-backend` (app-level: errors,
latency, automation, backend CPU/memory) and `infrastructure` (host-level:
CPU/memory/disk, Postgres/Redis reachability). Route `severity: critical`
to a page (PagerDuty/Opsgenie/phone call); route `severity: warning` to a
Slack channel — nothing here should page at 3am for a warning-level alert.

## Adding a new metric

1. Define it in `backend/src/metrics.js` (Counter/Histogram/Gauge from
   `prom-client`).
2. Increment/observe it at the relevant call site (see how
   `automationActionsTotal` is used in `automation.js` as the pattern).
3. Add a panel to `monitoring/grafana/dashboards/daily-overview.json`, or
   just build one ad-hoc in the Grafana UI first and export the JSON once
   it's useful enough to keep.

## Log-based investigation (no dashboard needed)

Every request is one structured JSON line (`backend/src/logger.js` +
`middleware/requestLogger.js`) — grep/jq work directly:

```bash
docker compose -f docker-compose.prod.yml logs backend | jq 'select(.res.statusCode >= 500)'
docker compose -f docker-compose.prod.yml logs backend | jq 'select(.userId == 42)'  # everything one user did
docker compose -f docker-compose.prod.yml logs backend | jq 'select(.responseTime > 1000)'  # slow requests
```
