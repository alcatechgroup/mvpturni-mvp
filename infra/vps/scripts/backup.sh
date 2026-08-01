#!/usr/bin/env bash
# Dump do Postgres da VPS para o bucket de backups (systemd timer diário).
#
# Com Cloud SQL, backup e point-in-time recovery vinham de graça. Numa VPS o banco é
# nosso — este script é o que sustenta a promessa de restore da ADR-004 (mantida pela
# ADR-021). A retenção é do bucket (lifecycle rule do Terraform), não daqui.
#
# Uso: backup.sh [rótulo]   — o rótulo entra no nome do arquivo (ex.: pre-deploy)
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/turni}"
# shellcheck disable=SC1091
set -a && . "$APP_DIR/runtime.env" && set +a
# shellcheck disable=SC1091
DB_PASSWORD="$(grep -E '^DB_PASSWORD=' "$APP_DIR/.env" | cut -d= -f2-)"

LABEL="${1:-auto}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FILE="/tmp/turni-${DEPLOY_ENV}-${STAMP}-${LABEL}.sql.gz"
DEST="gs://${BACKUP_BUCKET}/postgres/${DEPLOY_ENV}/$(basename "$FILE")"

echo "[$(date -Is)] dump de ${DB_DATABASE}"

# --clean --if-exists deixa o dump auto-suficiente: restaurar não exige banco vazio.
docker compose --project-directory "$APP_DIR" -f "$APP_DIR/docker-compose.yml" \
  exec -T -e PGPASSWORD="$DB_PASSWORD" postgres \
  pg_dump -U "$DB_USERNAME" -d "$DB_DATABASE" --clean --if-exists \
  | gzip -9 > "$FILE"

# Um dump vazio é pior que nenhum: passa despercebido até a hora do restore.
SIZE=$(stat -c %s "$FILE")
if [ "$SIZE" -lt 1024 ]; then
  echo "!! dump com ${SIZE} bytes — suspeito de falha; NÃO enviando"
  rm -f "$FILE"
  exit 1
fi

echo "[$(date -Is)] enviando $DEST (${SIZE} bytes)"
gcloud storage cp "$FILE" "$DEST" --quiet
rm -f "$FILE"

echo "[$(date -Is)] backup concluído"
