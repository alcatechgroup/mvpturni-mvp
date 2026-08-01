#!/usr/bin/env bash
# Restaura um dump do bucket de backups para o Postgres da VPS.
#
#   restore.sh                       lista os dumps disponíveis
#   restore.sh <objeto-gs://...>     restaura o dump indicado
#
# DESTRUTIVO: o dump é gerado com --clean --if-exists, então derruba e recria os
# objetos do banco alvo. Exige confirmação digitada.
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/turni}"
# shellcheck disable=SC1091
set -a && . "$APP_DIR/runtime.env" && set +a
DB_PASSWORD="$(grep -E '^DB_PASSWORD=' "$APP_DIR/.env" | cut -d= -f2-)"

COMPOSE="docker compose --project-directory $APP_DIR -f $APP_DIR/docker-compose.yml"

if [ $# -eq 0 ]; then
  echo "Dumps disponíveis em gs://${BACKUP_BUCKET}/postgres/${DEPLOY_ENV}/:"
  gcloud storage ls "gs://${BACKUP_BUCKET}/postgres/${DEPLOY_ENV}/" | tail -20
  echo
  echo "uso: restore.sh gs://.../turni-${DEPLOY_ENV}-....sql.gz"
  exit 0
fi

SRC="$1"
echo "ATENÇÃO: isto SOBRESCREVE o banco ${DB_DATABASE} do ambiente ${DEPLOY_ENV}."
echo "Origem: $SRC"
read -r -p "Digite o nome do ambiente (${DEPLOY_ENV}) para confirmar: " confirm
[ "$confirm" = "$DEPLOY_ENV" ] || { echo "cancelado"; exit 1; }

TMP="/tmp/restore-$(date -u +%s).sql.gz"
gcloud storage cp "$SRC" "$TMP" --quiet

# Parar quem escreve evita restaurar sobre transações em voo. O Caddy fica de pé:
# quem acessar recebe 502 do upstream, e não uma página meio restaurada.
echo "-- parando api, admin, worker e scheduler"
$COMPOSE stop api admin worker scheduler

echo "-- restaurando"
gunzip -c "$TMP" | $COMPOSE exec -T -e PGPASSWORD="$DB_PASSWORD" postgres \
  psql -U "$DB_USERNAME" -d "$DB_DATABASE" -v ON_ERROR_STOP=1

echo "-- subindo os serviços"
$COMPOSE start api admin worker scheduler
rm -f "$TMP"

echo "restore concluído"
