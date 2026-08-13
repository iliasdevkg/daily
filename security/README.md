# Security Infrastructure

What's in this repo vs. what needs an external account/service signup.

## In this repo (ready to use)

- **fail2ban** — `security/fail2ban/` — IP banning after repeated auth
  failures, install on the production host directly (see comments in
  `jail.local`).
- **Rate limiting** — two layers: `backend/src/app.js` (application-level,
  per-JWT-independent) and `nginx/nginx.conf` (`limit_req_zone`, edge-level,
  catches floods before they reach the app at all).
- **Secrets never in git** — `.env`/`.env.production` are gitignored;
  `.env.example` documents every key name with no real values. CI/CD
  (`.github/workflows/ci-cd.yml`) reads secrets from GitHub's own Secrets
  store (`secrets.*`), never from a committed file.
- **TLS** — `nginx/nginx.conf` terminates HTTPS with TLS 1.2/1.3 only,
  HSTS, and `scripts/init-letsencrypt.sh` issues + auto-renews real
  certificates (the `certbot` service in `docker-compose.prod.yml` renews
  every 12h).
- **Audit logs** — `order_history` table (who did what to which order,
  already built) + structured request logs (`backend/src/logger.js`, every
  request with user ID/role/IP/route) double as an access audit trail.

## Needs an external account (can't be provisioned from code)

| Layer | What it does | Setup |
|---|---|---|
| **Cloudflare** | DNS, CDN, a free-tier WAF, DDoS mitigation in front of everything | Sign up at cloudflare.com, point the domain's nameservers at Cloudflare, enable "Under Attack Mode" as a manual DDoS lever, turn on their managed WAF ruleset (free tier includes OWASP core rules) |
| **Secrets Manager** | Rotate JWT_SECRET/DB passwords without editing `.env` files by hand | AWS Secrets Manager, Doppler, or 1Password Secrets Automation — any of them can inject env vars into the container at start instead of `env_file:` in `docker-compose.prod.yml` |
| **Sentry** (error tracking is already wired, see `backend/src/sentry.js`) | Needs a project + `SENTRY_DSN` | sentry.io → New Project → Node.js → copy the DSN into `.env.production` |
| **Managed Postgres/Redis** | Automated backups, failover, read replicas without operating them yourself | Supabase (Postgres — already referenced in `render.yaml`), Upstash or Redis Cloud (Redis) |

## Certificate rotation

Handled automatically by the `certbot` service in `docker-compose.prod.yml`
(loops every 12h, renews if within 30 days of expiry — Let's Encrypt certs
are valid 90 days). No manual rotation needed once
`scripts/init-letsencrypt.sh` has run once.

## IP reputation

Not implemented — would need a paid threat-intelligence feed (e.g.
Cloudflare's IP reputation on a paid plan, or MaxMind) to block known-bad
IPs before they hit rate limiting. fail2ban above is the local equivalent
(reactive, based on this app's own logs, not a global reputation feed).
