# Deployment Guide

## Option A — Render (current, simplest)

Already configured (`render.yaml`), no Redis/queue. Push to `main`,
Render auto-deploys. Add `REDIS_URL` as an environment variable (a Render
Key-Value instance, or Upstash) to enable Redis mode with zero code
changes — `bus.js`/`queue.js` detect it automatically.

## Option B — Docker Compose on a VM (full stack)

```bash
# One-time, on the production host, DNS already pointing here:
cp backend/.env.example backend/.env.production   # fill in real values
cp .env.example .env                              # fill in DB_PASSWORD etc.
LETSENCRYPT_EMAIL=you@example.com ./scripts/init-letsencrypt.sh

docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml ps      # confirm everything is healthy
```

Scale workers independently of the API:

```bash
docker compose -f docker-compose.prod.yml up -d --scale worker=3
```

Roll out a new backend build:

```bash
docker compose -f docker-compose.prod.yml build backend worker
docker compose -f docker-compose.prod.yml up -d --no-deps backend worker
```

## Option C — Plain VM with PM2 (no Docker)

```bash
cd backend
npm ci --omit=dev
cp .env.example .env  # fill in real values
npx pm2 start ecosystem.config.js --env production
npx pm2 save
npx pm2 startup  # follow the printed instructions to survive a reboot
```

## Local development

```bash
docker compose up          # postgres + redis + backend + admin-web + frontend, hot-reload
# or, without Docker:
cd backend && npm install && npm run dev
```

## CI/CD

`.github/workflows/ci-cd.yml` runs on every push to `main`: lint → test
(against real Postgres+Redis service containers) → build every frontend
app → security scan (npm audit + Trivy) → Docker build+push to GHCR →
deploy (triggers Render's deploy hook) → wait for health → smoke test →
rollback instructions on failure.

Required repo secrets: `RENDER_DEPLOY_HOOK_URL`, `PRODUCTION_HEALTH_URL`.
Without them, the deploy job logs a message and exits 0 rather than
failing the whole pipeline — useful for running the pipeline on a fork or
before deployment is wired up.

## Pre-deployment checklist

- [ ] `npm test` passes locally (12+ tests, `backend/test/`)
- [ ] `JWT_SECRET` is a real random value, not the dev default
- [ ] `ALLOWED_ORIGINS` lists the real frontend domains
- [ ] `DATABASE_URL` points at the production database, migrations will
      run automatically on startup (`migrations.js`)
- [ ] If using Redis: `REDIS_URL` set on **every** backend/worker instance
      — a mixed fleet (some with Redis, some without) means SSE clients on
      different instances see different events
- [ ] `SENTRY_DSN` set if error tracking is wanted
- [ ] TLS certificates issued (`scripts/init-letsencrypt.sh`) if using the
      nginx/Docker path
