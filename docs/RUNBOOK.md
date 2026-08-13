# Runbook

Common operational tasks, with the exact command for each.

## Check if the system is healthy

```bash
curl https://api.daily.kg/api/health   # always 200 if the process can respond at all
curl https://api.daily.kg/api/ready    # 200 only if DB/Redis/queue/disk/memory are all OK
curl https://api.daily.kg/api/live     # Kubernetes-style liveness, no dependency checks
```

Or check Grafana → Daily → Backend Overview dashboard for the full picture.

## An order is stuck (automation didn't progress it)

```bash
curl -H "Authorization: Bearer $ADMIN_TOKEN" https://api.daily.kg/api/settings/automation-errors
```

Each row: `order_id`, `step` (the status it was stuck on), `error_message`.
`automation.js`'s `sweep()` retries every 60s automatically for anything
still matching its criteria — if it's still showing up after several
minutes, the error message says why (usually a downstream constraint
violation). Fix the root cause, then either wait for the next sweep or
force one: `PUT /api/settings/automation` with any no-op patch (e.g.
`{"autoConfirm": true}`) re-triggers `sweep()` immediately.

## A queue job is stuck / failing repeatedly

```bash
curl -H "Authorization: Bearer $ADMIN_TOKEN" https://api.daily.kg/api/ready
# → checks.queue.queues.<name>.failed and .deadLetter counts
```

Failed jobs are visible in Redis directly for deeper inspection:

```bash
redis-cli -u $REDIS_URL
> LRANGE bull:notifications:failed 0 -1
```

Jobs that exhausted all 5 retry attempts land in the `dead-letter` queue
(`queue.js`) — inspect and manually replay or discard:

```bash
redis-cli -u $REDIS_URL LRANGE bull:dead-letter:waiting 0 -1
```

## Restart the backend

```bash
# Docker:
docker compose -f docker-compose.prod.yml restart backend
# PM2:
pm2 restart daily-api
```

Graceful — `app.js`'s SIGTERM handler stops accepting new connections,
finishes in-flight requests (up to 10s), closes DB/Redis/queue cleanly.
No requests are dropped mid-flight under normal restart.

## Roll back a bad deploy

**Render**: Dashboard → the service → Deploys tab → find the last-known-good
deploy → "Rollback to this deploy".

**Docker Compose**:
```bash
docker compose -f docker-compose.prod.yml pull backend  # or build a specific tag
docker compose -f docker-compose.prod.yml up -d --no-deps backend
```

## Rotate JWT_SECRET

Invalidates every existing session immediately (all users must log in
again — there's no refresh-token mechanism today, see the security audit).

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
# set the new value in backend/.env.production (or the hosting platform's
# secret store), then restart every backend/worker instance
```

## Check current automation/earnings settings

```bash
curl -H "Authorization: Bearer $ADMIN_TOKEN" https://api.daily.kg/api/settings/automation
curl -H "Authorization: Bearer $ADMIN_TOKEN" https://api.daily.kg/api/earnings/rates
```

## Tail structured logs

```bash
# Docker:
docker compose -f docker-compose.prod.yml logs -f backend | jq .
# Filter to errors only:
docker compose -f docker-compose.prod.yml logs -f backend | jq 'select(.level=="error")'
```

## Manually trigger a backup

```bash
DATABASE_URL=$DATABASE_URL REDIS_URL=$REDIS_URL ./scripts/backup.sh
```

## Renew TLS certificates manually (normally automatic)

```bash
docker compose -f docker-compose.prod.yml exec certbot certbot renew --webroot -w /var/www/certbot
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```
