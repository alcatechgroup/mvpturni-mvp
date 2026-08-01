#!/usr/bin/env bash
# Deploy de uma release na VPS. Chamado pelo pipeline por SSH via túnel IAP:
#
#   gcloud compute ssh turni-homolog-vm --tunnel-through-iap \
#     --command "sudo /opt/turni/scripts/deploy.sh v1.2.3"
#
# Também serve para operar à mão (rollback, ressincronizar config).
#
# Uso:
#   deploy.sh <tag>            aplica a tag (o caminho normal)
#   deploy.sh --sync           só ressincroniza config/segredos e recarrega
#   deploy.sh --rollback       volta para a tag anterior registrada
#
# Migração é FORWARD-ONLY (quality-standards 2.4): o rollback devolve o CÓDIGO, não
# o schema. Reverter schema é migração nova de correção.
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/turni}"
STATE_DIR="$APP_DIR/.state"
CURRENT_TAG_FILE="$STATE_DIR/current_tag"
PREVIOUS_TAG_FILE="$STATE_DIR/previous_tag"
COMPOSE="docker compose --project-directory $APP_DIR -f $APP_DIR/docker-compose.yml"

mkdir -p "$STATE_DIR"
cd "$APP_DIR"

log() { echo "[$(date -Is)] $*"; }

sync_config() {
  local bucket keep_tag=""
  bucket="$(grep -E '^CONFIG_BUCKET=' "$APP_DIR/runtime.env" 2>/dev/null | cut -d= -f2- || true)"
  [ -f "$CURRENT_TAG_FILE" ] && keep_tag="$(cat "$CURRENT_TAG_FILE")"

  if [ -n "$bucket" ]; then
    log "sincronizando runtime de gs://$bucket"
    # SEM --delete: o destino é /opt/turni, que também guarda .env, .env.admin e
    # .state/ — arquivos que não existem no bucket e seriam apagados.
    gcloud storage rsync --recursive "gs://$bucket/runtime" "$APP_DIR" --quiet
    gcloud storage cp "gs://$bucket/runtime.env" "$APP_DIR/runtime.env" --quiet
    chmod +x "$APP_DIR"/scripts/*.sh
  fi

  # O runtime.env recém-baixado traz IMAGE_TAG=latest (valor de bootstrap). Sem
  # restaurar a tag corrente, um `--sync` degradaria a release em produção.
  [ -n "$keep_tag" ] && set_tag "$keep_tag"

  "$APP_DIR/scripts/render-env.sh"
}

set_tag() {
  local tag="$1"
  # sed -i em vez de reescrever: o runtime.env é gerado pelo Terraform e só a tag
  # muda entre deploys.
  if grep -qE '^IMAGE_TAG=' "$APP_DIR/runtime.env"; then
    sed -i "s|^IMAGE_TAG=.*|IMAGE_TAG=${tag}|" "$APP_DIR/runtime.env"
  else
    echo "IMAGE_TAG=${tag}" >> "$APP_DIR/runtime.env"
  fi
  "$APP_DIR/scripts/render-env.sh"
}

health_check() {
  local tries=30
  log "aguardando a api responder /health"
  until $COMPOSE exec -T api wget -qO- http://127.0.0.1:8080/health >/dev/null 2>&1; do
    tries=$((tries - 1))
    if [ "$tries" -le 0 ]; then
      log "!! /health não respondeu — a release NÃO está saudável"
      $COMPOSE ps
      return 1
    fi
    sleep 5
  done
  log "api saudável"
}

case "${1:-}" in
  --sync)
    log "ressincronizando configuração e segredos"
    sync_config
    $COMPOSE up -d --remove-orphans
    health_check
    exit 0
    ;;
  --rollback)
    [ -f "$PREVIOUS_TAG_FILE" ] || { log "!! sem tag anterior registrada"; exit 1; }
    TAG="$(cat "$PREVIOUS_TAG_FILE")"
    log "ROLLBACK para $TAG (schema NÃO é revertido — forward-only)"
    ;;
  "")
    echo "uso: deploy.sh <tag> | --sync | --rollback" >&2
    exit 2
    ;;
  *)
    TAG="$1"
    ;;
esac

log "=== deploy da tag $TAG ==="

sync_config
set_tag "$TAG"

log "puxando imagens"
$COMPOSE pull --quiet

# O Postgres precisa estar de pé ANTES da migração — e o `up` dele é idempotente.
log "garantindo o banco no ar"
$COMPOSE up -d postgres
$COMPOSE exec -T postgres sh -c 'until pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do sleep 2; done'

# Migração ANTES de trocar o tráfego: o schema fica pronto para o código novo.
# `--force` porque APP_ENV=production pede confirmação interativa.
log "aplicando migrações"
$COMPOSE run --rm --no-deps api php artisan migrate --force

log "subindo a stack"
$COMPOSE up -d --remove-orphans

log "limpando e reaquecendo caches do Laravel"
$COMPOSE exec -T api php artisan config:cache || true
$COMPOSE exec -T api php artisan route:cache || true
$COMPOSE exec -T admin php artisan config:cache || true

if health_check; then
  # Só registra a tag anterior num deploy que ficou saudável — senão o --rollback
  # apontaria para uma release quebrada.
  if [ -f "$CURRENT_TAG_FILE" ] && [ "$(cat "$CURRENT_TAG_FILE")" != "$TAG" ]; then
    cp "$CURRENT_TAG_FILE" "$PREVIOUS_TAG_FILE"
  fi
  echo "$TAG" > "$CURRENT_TAG_FILE"
  log "=== deploy de $TAG concluído ==="
else
  log "!! deploy de $TAG falhou no health check — rode 'deploy.sh --rollback'"
  exit 1
fi

# Higiene: imagens antigas enchem o disco de boot (20 GB) em poucas dezenas de deploys.
docker image prune -af --filter "until=168h" >/dev/null 2>&1 || true
