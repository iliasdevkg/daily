#!/usr/bin/env bash
# Restores Postgres from a backup produced by scripts/backup.sh. Destructive
# by nature (drops and recreates data) — confirms before running, and
# refuses to run against a DATABASE_URL that looks like production unless
# --force is passed, as a speed bump against restoring over live data by
# mistake.
#
# Usage: DATABASE_URL=... ./scripts/restore.sh backups/daily/postgres-20260716.sql.gz [--force]
set -euo pipefail

FILE="${1:?Usage: DATABASE_URL=... ./scripts/restore.sh <backup-file.sql.gz> [--force]}"
FORCE="${2:-}"

if [ -z "${DATABASE_URL:-}" ]; then
  echo "DATABASE_URL зайыгы табылган жок" >&2
  exit 1
fi

if [[ "$DATABASE_URL" == *"prod"* || "$DATABASE_URL" == *"supabase.com"* ]] && [ "$FORCE" != "--force" ]; then
  echo "DATABASE_URL production'го окшойт. Эгер чын эле каалаганыңыз болсо, --force кошуп кайра иштетиңиз." >&2
  echo "  DATABASE_URL=... ./scripts/restore.sh $FILE --force" >&2
  exit 1
fi

echo "Бул '$DATABASE_URL' базасынын учурдагы бардык маалыматын '$FILE' менен алмаштырат."
read -r -p "Улантуу үчүн 'restore' деп жазыңыз: " CONFIRM
if [ "$CONFIRM" != "restore" ]; then
  echo "Токтотулду." >&2
  exit 1
fi

echo "Калыбына келтирүү башталды: $(date)" >&2
gunzip -c "$FILE" | psql "$DATABASE_URL"
echo "Калыбына келтирүү аяктады: $(date)" >&2
echo "Текшерүү: SELECT COUNT(*) FROM orders; сыяктуу суроо менен маалыматты текшериңиз."
