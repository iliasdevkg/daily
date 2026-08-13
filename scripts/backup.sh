#!/usr/bin/env bash
# Backs up Postgres (pg_dump) and Redis (RDB snapshot copy), keeps daily
# backups for 7 days, weekly for 4 weeks, monthly for 6 months. Meant to
# run from cron on the production host — see the crontab lines at the
# bottom of this file's comments.
#
# Usage: DATABASE_URL=... ./scripts/backup.sh
#   (Redis backup is skipped automatically if REDIS_URL isn't set)
set -euo pipefail

BACKUP_ROOT="${BACKUP_DIR:-./backups}"
TODAY=$(date +%Y%m%d)
DOW=$(date +%u)   # 1=Monday..7=Sunday
DOM=$(date +%d)   # day of month

mkdir -p "$BACKUP_ROOT"/{daily,weekly,monthly}

# ── Postgres ────────────────────────────────────────────────────────────
if [ -n "${DATABASE_URL:-}" ]; then
  PG_FILE="$BACKUP_ROOT/daily/postgres-$TODAY.sql.gz"
  echo "Postgres backup: $PG_FILE" >&2
  pg_dump "$DATABASE_URL" | gzip > "$PG_FILE"

  # Sunday's daily backup is also kept as this week's weekly snapshot.
  [ "$DOW" = "7" ] && cp "$PG_FILE" "$BACKUP_ROOT/weekly/postgres-week-$(date +%Y-W%V).sql.gz"
  # The 1st-of-month backup is also kept as this month's monthly snapshot.
  [ "$DOM" = "01" ] && cp "$PG_FILE" "$BACKUP_ROOT/monthly/postgres-$(date +%Y-%m).sql.gz"
else
  echo "DATABASE_URL жок — Postgres backup өткөрүлүп жиберилди" >&2
fi

# ── Redis ───────────────────────────────────────────────────────────────
# Assumes redis-cli can reach the instance and BGSAVE is permitted (managed
# Redis providers like Upstash/Redis Cloud handle their own backups — this
# path is for a self-hosted docker-compose.prod.yml Redis).
if [ -n "${REDIS_URL:-}" ]; then
  RDB_FILE="$BACKUP_ROOT/daily/redis-$TODAY.rdb"
  echo "Redis backup: $RDB_FILE" >&2
  redis-cli -u "$REDIS_URL" --rdb "$RDB_FILE" >/dev/null
  [ "$DOW" = "7" ] && cp "$RDB_FILE" "$BACKUP_ROOT/weekly/redis-week-$(date +%Y-W%V).rdb"
  [ "$DOM" = "01" ] && cp "$RDB_FILE" "$BACKUP_ROOT/monthly/redis-$(date +%Y-%m).rdb"
else
  echo "REDIS_URL жок — Redis backup өткөрүлүп жиберилди (queue иштери кайра түзүлө алат, жоготуу коркунучу төмөн)" >&2
fi

# ── Retention ───────────────────────────────────────────────────────────
find "$BACKUP_ROOT/daily" -type f -mtime +7 -delete
find "$BACKUP_ROOT/weekly" -type f -mtime +28 -delete
find "$BACKUP_ROOT/monthly" -type f -mtime +186 -delete

echo "Backup аяктады: $(date)" >&2

# ── Cron жабдуу (crontab -e) ────────────────────────────────────────────
# 0 3 * * * cd /path/to/daily_all_system && DATABASE_URL=... REDIS_URL=... ./scripts/backup.sh >> /var/log/daily-backup.log 2>&1
