#!/usr/bin/env bash
# scripts/verify-deployment.sh — Stage 5: Production Verification.
#
# Checks, in order: Backend, Frontend, Admin, PostgreSQL, Redis, Queue,
# Automation, SSE, Health endpoint, Metrics. Prints PASS/FAIL/SKIP per
# check and exits non-zero if anything required actually failed.
#
# Usage (real server, once DNS+HTTPS are live):
#   BACKEND_URL=https://api.daily.kg \
#   FRONTEND_URL=https://daily.kg \
#   ADMIN_URL=https://admin.daily.kg \
#   ./scripts/verify-deployment.sh
#
# Usage (local smoke test — same checks, no domain/TLS needed):
#   ./scripts/verify-deployment.sh
#   (defaults to http://localhost:3001 for backend, skips frontend/admin
#   checks if those dev servers aren't running on the assumed ports)
set -uo pipefail

BACKEND_URL="${BACKEND_URL:-http://localhost:3001}"
FRONTEND_URL="${FRONTEND_URL:-}"
ADMIN_URL="${ADMIN_URL:-}"

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "  \033[1;32mPASS\033[0m $1"; PASS=$((PASS+1)); }
failed() { echo -e "  \033[1;31mFAIL\033[0m $1"; FAIL=$((FAIL+1)); }
skip() { echo -e "  \033[1;33mSKIP\033[0m $1"; SKIP=$((SKIP+1)); }
section() { echo -e "\n\033[1;34m$1\033[0m"; }

# 1. Backend --------------------------------------------------------------
section "1/10 Backend ($BACKEND_URL/api/health)"
BODY=$(curl -fsS -m 5 "$BACKEND_URL/api/health" 2>&1)
if [[ $? -eq 0 ]] && echo "$BODY" | grep -q '"status":"OK"'; then
  pass "backend жооп берет: $BODY"
else
  failed "backend жеткиликсиз же күтүлбөгөн жооп: $BODY"
fi

# 2. Frontend ---------------------------------------------------------------
section "2/10 Frontend"
if [[ -n "$FRONTEND_URL" ]]; then
  if curl -fsS -m 5 "$FRONTEND_URL" 2>&1 | grep -qi "<html"; then
    pass "frontend HTML кайтарат ($FRONTEND_URL)"
  else
    failed "frontend жеткиликсиз ($FRONTEND_URL)"
  fi
else
  skip "FRONTEND_URL берилген жок"
fi

# 3. Admin --------------------------------------------------------------------
section "3/10 Admin"
if [[ -n "$ADMIN_URL" ]]; then
  if curl -fsS -m 5 "$ADMIN_URL" 2>&1 | grep -qi "<html"; then
    pass "admin-web HTML кайтарат ($ADMIN_URL)"
  else
    failed "admin-web жеткиликсиз ($ADMIN_URL)"
  fi
else
  skip "ADMIN_URL берилген жок"
fi

# 4-7: /api/ready aggregates database/redis/queue in one call. No -f here
# on purpose — /ready intentionally returns 503 when e.g. disk/memory are
# low even though database/redis/queue are fine, and -f would discard the
# JSON body on any non-2xx, hiding exactly the detail this script needs.
READY_JSON=$(curl -sS -m 5 "$BACKEND_URL/api/ready" 2>&1)
READY_STATUS=$(curl -s -o /dev/null -w '%{http_code}' -m 5 "$BACKEND_URL/api/ready" 2>&1)

section "4/10 PostgreSQL"
if echo "$READY_JSON" | grep -q '"database":{"ok":true'; then
  pass "database check ok"
else
  failed "database check жок же ok:false — $READY_JSON"
fi

section "5/10 Redis"
if echo "$READY_JSON" | grep -q '"redis":{"ok":true'; then
  pass "redis pub/sub ok"
elif echo "$READY_JSON" | grep -q '"redis"'; then
  failed "redis конфигурацияланган бирок ok:false — $READY_JSON"
else
  skip "REDIS_URL коюлган эмес окшойт — single-instance режим (жарактуу конфигурация, бирок >1 backend replica'да сунушталбайт)"
fi

section "6/10 Queue (BullMQ)"
if echo "$READY_JSON" | grep -q '"queue":{"ok":true'; then
  pass "queue counts алынды"
elif echo "$READY_JSON" | grep -q '"queue"'; then
  failed "queue конфигурацияланган бирок ok:false — $READY_JSON"
else
  skip "Redis жок болгондуктан queue да локалдуу режимде (Redis check менен бирдей себеп)"
fi

section "7/10 Automation"
# There is no unauthenticated automation-status endpoint by design
# (/api/settings/automation requires an admin JWT) — this script has no
# credentials to obtain one. What CAN be verified without auth: the
# process is up (check 1) and its actual dependencies — database, and
# redis/queue if configured — are healthy, which together are necessary
# for automation's sweep() to run. Deliberately NOT gated on the full
# /ready 200 status: /ready also fails on disk/memory pressure, which is
# unrelated to whether automation itself can function. Full behavioral
# proof that automation actually confirms/assigns/completes real orders
# is the job of Stage 6's acceptance test, not this script.
DB_OK=$(echo "$READY_JSON" | grep -q '"database":{"ok":true' && echo yes || echo no)
REDIS_BAD=$(echo "$READY_JSON" | grep -q '"redis":{"ok":false' && echo yes || echo no)
QUEUE_BAD=$(echo "$READY_JSON" | grep -q '"queue":{"ok":false' && echo yes || echo no)
if [[ "$DB_OK" == "yes" && "$REDIS_BAD" == "no" && "$QUEUE_BAD" == "no" ]]; then
  pass "automation sweep'и үчүн зарыл көз карандылыктар (database, redis/queue) даяр — толук поведенческий текшерүү Stage 6'да"
else
  failed "automation'дун көз карандылыктарынан бирөө бузук — $READY_JSON"
fi

# 8. SSE ------------------------------------------------------------------
section "8/10 SSE (/api/events)"
SSE_STATUS=$(curl -s -o /dev/null -w '%{http_code}' -m 5 "$BACKEND_URL/api/events" 2>&1)
if [[ "$SSE_STATUS" == "401" ]]; then
  pass "endpoint жеткиликтүү жана auth талап кылат (401 токенсиз — күтүлгөн жооп)"
elif [[ "$SSE_STATUS" == "404" || "$SSE_STATUS" == "502" || "$SSE_STATUS" == "000" ]]; then
  failed "SSE endpoint жеткиликсиз (status=$SSE_STATUS) — nginx /api proxy же route туура эмес болушу мүмкүн"
else
  failed "күтүлбөгөн статус: $SSE_STATUS (401 болушу керек эле)"
fi

# 9. Health endpoint (/live + /ready together) -------------------------------
section "9/10 Health endpoint (/api/live, /api/ready)"
LIVE_STATUS=$(curl -s -o /dev/null -w '%{http_code}' -m 5 "$BACKEND_URL/api/live" 2>&1)
if [[ "$LIVE_STATUS" == "200" ]]; then
  pass "/api/live 200"
else
  failed "/api/live status=$LIVE_STATUS"
fi
if [[ "$READY_STATUS" == "200" ]]; then
  pass "/api/ready 200 — $READY_JSON"
else
  # A 503 here is the endpoint doing its job (any single check failing
  # correctly fails the whole probe) — still reported as FAIL for this
  # script's pass/fail count since "not ready" is not ready, but the
  # detail printed tells you whether the cause is infra-level (disk/
  # memory on THIS host) or an actual dependency outage (database/redis).
  failed "/api/ready status=$READY_STATUS — $READY_JSON"
fi

# 10. Metrics -----------------------------------------------------------------
section "10/10 Metrics (/metrics)"
METRICS=$(curl -fsS -m 5 "$BACKEND_URL/metrics" 2>&1)
if echo "$METRICS" | grep -q "^# HELP daily_"; then
  pass "Prometheus форматында daily_* метрикалар бар"
else
  failed "/metrics жеткиликсиз же Prometheus форматында эмес"
fi

# --- Summary -----------------------------------------------------------------
echo -e "\n\033[1;34m====================================\033[0m"
echo -e "PASS: $PASS   FAIL: $FAIL   SKIP: $SKIP"
echo -e "\033[1;34m====================================\033[0m"
[[ "$FAIL" -eq 0 ]] || exit 1
