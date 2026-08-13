#!/usr/bin/env bash
# scripts/deploy.sh — deploy Daily to a fresh Ubuntu 24.04 host.
#
# Prerequisites (do these first, they are NOT part of this script):
#   1. Run server-setup.sh once as a sudo-capable user (Docker, UFW,
#      Fail2Ban, swap, Node, etc.) — see that script's own header.
#   2. Log in as the 'deploy' user server-setup.sh created (or any user in
#      the docker group).
#   3. cp backend/.env.example backend/.env.production and fill in real
#      values (JWT_SECRET, DATABASE_URL or DB_*, REDIS_URL, ALLOWED_ORIGINS,
#      SENTRY_DSN, ...). This file is gitignored — deploy.sh never creates
#      or touches it, only checks that it exists.
#   4. cp .env.example .env (repo root) and fill in DB_NAME/DB_USER/
#      DB_PASSWORD/GRAFANA_ADMIN_PASSWORD/LETSENCRYPT_EMAIL — this is the
#      SEPARATE var set docker-compose.prod.yml's own ${VAR} substitution
#      reads (env_file: only injects into the container, it does not feed
#      compose's own variable interpolation — see that file's comments).
#   5. Point DNS (api./admin./daily.<domain>) at this host, then run
#      ./scripts/init-letsencrypt.sh before nginx can serve HTTPS (see
#      Stage 4). Until certs exist, comment out the nginx/certbot services
#      or nginx will fail to start on missing cert paths.
#
# Usage:
#   ./scripts/deploy.sh                 # clone-less: deploy from the
#                                        # current working copy (already
#                                        # cloned/pulled) — default.
#   REPO_URL=https://github.com/iliasdevkg/daily_all_system.git \
#   DEPLOY_DIR=/opt/daily ./scripts/deploy.sh --clone
#                                        # fresh clone into DEPLOY_DIR first
#
# Idempotent: safe to re-run for a redeploy (git pull + rebuild + restart).
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/iliasdevkg/daily_all_system.git}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/daily}"
COMPOSE_FILE="docker-compose.prod.yml"
HEALTH_URL="${HEALTH_URL:-http://localhost/api/health}"
HEALTH_RETRIES="${HEALTH_RETRIES:-30}"
HEALTH_INTERVAL="${HEALTH_INTERVAL:-5}"

log()  { echo -e "\n\033[1;34m==>\033[0m $1"; }
ok()   { echo -e "\033[1;32m✓\033[0m $1"; }
fail() { echo -e "\033[1;31m✗\033[0m $1"; exit 1; }

# --- 0. Clone (only with --clone; otherwise deploy from $PWD) --------------
if [[ "${1:-}" == "--clone" ]]; then
  log "GitHub'дан clone: $REPO_URL -> $DEPLOY_DIR"
  if [[ -d "$DEPLOY_DIR/.git" ]]; then
    ok "$DEPLOY_DIR already a git checkout — pulling instead of cloning"
    git -C "$DEPLOY_DIR" pull --ff-only
  else
    sudo mkdir -p "$DEPLOY_DIR"
    sudo chown "$(id -u):$(id -g)" "$DEPLOY_DIR"
    git clone "$REPO_URL" "$DEPLOY_DIR"
  fi
  cd "$DEPLOY_DIR"
else
  log "--clone эмес — учурдагы каталогдон deploy кылынат: $(pwd)"
  [[ -f "$COMPOSE_FILE" ]] || fail "$COMPOSE_FILE табылган жок. Repo root'то иштет же --clone колдон."
fi

# --- 1. Preflight: required env files must already exist -------------------
log "Preflight: milдеттүү env файлдарын текшерүү"
[[ -f backend/.env.production ]] || fail "backend/.env.production жок. Алгач backend/.env.example'ден копия жаса жана толтур."
[[ -f .env ]] || fail "Root .env жок. Алгач .env.example'ден копия жаса жана толтур (DB_NAME/DB_USER/DB_PASSWORD/...)."
grep -q '^JWT_SECRET=.\+' backend/.env.production || fail "JWT_SECRET бош. backend/.env.production ичинде толтур."
grep -q '^DB_PASSWORD=.\+' .env || fail "DB_PASSWORD бош. .env ичинде толтур."
ok "Env файлдары бар жана негизги талаптар толтурулган"

command -v docker >/dev/null || fail "docker табылган жок. server-setup.sh'ты алгач иштет."
docker compose version >/dev/null 2>&1 || fail "docker compose (plugin) табылган жок."
ok "Docker жана Docker Compose даяр"

# --- 2. Docker Build ---------------------------------------------------------
log "Docker Build: бардык image'дерди куруу"
docker compose -f "$COMPOSE_FILE" build --pull
ok "Image'дер курулду"

# --- 3. Database Init + Migration --------------------------------------------
# postgres's docker-entrypoint-initdb.d/init.sql only runs on a BRAND NEW
# (empty) data volume — that's "Database Init" (roles + base schema). Actual
# schema evolution ("Migration") happens automatically on backend startup —
# migrations.run() in app.js, tracked in the migrations_log table, safe to
# run every deploy since each migration is idempotent/run-once.
log "Postgres жана Redis'ти алгач көтөрүү (Database Init үчүн)"
docker compose -f "$COMPOSE_FILE" up -d postgres redis

log "Postgres'тин даяр болушун күтүү"
for i in $(seq 1 "$HEALTH_RETRIES"); do
  if docker compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U "${DB_USER:-postgres}" >/dev/null 2>&1; then
    ok "Postgres даяр"
    break
  fi
  [[ "$i" -eq "$HEALTH_RETRIES" ]] && fail "Postgres $((HEALTH_RETRIES * HEALTH_INTERVAL))s ичинде даяр болгон жок"
  sleep "$HEALTH_INTERVAL"
done

# --- 4. Container Startup ----------------------------------------------------
log "Калган бардык кызматтарды көтөрүү (backend, worker, admin-web, frontend, nginx, monitoring)"
docker compose -f "$COMPOSE_FILE" up -d
ok "docker compose up -d аткарылды — migrations.run() backend'дин startup'унда автоматту түрдө иштейт"

# --- 5. Seed (idempotent — safe on redeploys, no-ops if data exists) --------
log "Seed: базалык категориялар/товарлар (жок болсо гана кошот)"
if docker compose -f "$COMPOSE_FILE" exec -T backend node scripts/seed.js; then
  ok "Seed аткарылды (же мурунтан бар болчу — ON CONFLICT DO NOTHING менен идемпотенттүү)"
else
  echo "  (seed кийинчерээк кол менен иштетилсин болот: docker compose -f $COMPOSE_FILE exec backend node scripts/seed.js)"
fi

# --- 6. Health Check ----------------------------------------------------------
log "Health check: $HEALTH_URL"
for i in $(seq 1 "$HEALTH_RETRIES"); do
  if curl -fsS "$HEALTH_URL" >/dev/null 2>&1; then
    ok "Backend $HEALTH_URL аркылуу жооп берет"
    break
  fi
  [[ "$i" -eq "$HEALTH_RETRIES" ]] && fail "Health check $((HEALTH_RETRIES * HEALTH_INTERVAL))s ичинде өтпөдү. Логдорду кара: docker compose -f $COMPOSE_FILE logs backend --tail=100"
  sleep "$HEALTH_INTERVAL"
done

log "Кызматтардын абалы"
docker compose -f "$COMPOSE_FILE" ps

echo -e "\n\033[1;32mDeploy аяктады.\033[0m Кийинки кадам: HTTPS үчүн ./scripts/init-letsencrypt.sh (эгер али иштетилбесе)."
