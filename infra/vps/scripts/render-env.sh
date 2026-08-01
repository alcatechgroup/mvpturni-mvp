#!/usr/bin/env bash
# Monta o /opt/turni/.env que o docker compose consome.
#
# Fonte dupla, de propósito (ADR-004 §f):
#   • runtime.env  — identidade NÃO-secreta do ambiente, gerada pelo Terraform e
#                    publicada no bucket de config;
#   • Secret Manager — os segredos, buscados AGORA com a identidade da instância.
#
# Nenhum segredo trafega pelo bucket, pelo git ou pelos metadados da VM. O arquivo
# resultante é 600/root e é recriado a cada boot e a cada deploy — rotacionar um
# segredo é publicar nova versão e rodar `deploy.sh --sync`.
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/turni}"
RUNTIME_ENV="$APP_DIR/runtime.env"
OUT="$APP_DIR/.env"
OUT_ADMIN="$APP_DIR/.env.admin"

[ -f "$RUNTIME_ENV" ] || { echo "!! $RUNTIME_ENV ausente — rode o bootstrap antes"; exit 1; }

# shellcheck disable=SC1090
set -a && . "$RUNTIME_ENV" && set +a

secret() {
  local name="$1"
  gcloud secrets versions access latest \
    --secret="${SECRET_PREFIX}-${name}" \
    --project="$GCP_PROJECT" 2>/dev/null
}

echo "-- lendo segredos de ${SECRET_PREFIX}-* no projeto $GCP_PROJECT"
APP_KEY_API="$(secret app-key-api)"
APP_KEY_ADMIN="$(secret app-key-admin)"
DB_PASSWORD="$(secret db-password)"
RESEND_API_KEY="$(secret resend-api-key)"
CLOUDFLARE_DNS_TOKEN="$(secret cloudflare-dns-token)"
PIX_FALHA_CHAVE_KEY="$(secret pix-falha-chave-key)"

# Segredos que só existem onde o fake de pagamento roda (homolog/staging).
PAGARME_SECRET_KEY="$(secret pagarme-secret-key || true)"
PAGARME_WEBHOOK_SECRET="$(secret pagarme-webhook-secret || true)"

for required in APP_KEY_API APP_KEY_ADMIN DB_PASSWORD CLOUDFLARE_DNS_TOKEN; do
  if [ -z "${!required}" ]; then
    echo "!! segredo obrigatório vazio: $required (verifique ${SECRET_PREFIX}-* no Secret Manager)"
    exit 1
  fi
done

# `fake` é o profile do pagarme-mock no compose. Em produção ENABLE_PAYMENT_FAKE é
# false, COMPOSE_PROFILES fica vazio e o container simplesmente não é instanciado.
COMPOSE_PROFILES=""
[ "${ENABLE_PAYMENT_FAKE:-false}" = "true" ] && COMPOSE_PROFILES="fake"

umask 077
cat > "$OUT" <<EOF
# GERADO por scripts/render-env.sh — não editar à mão (recriado a cada deploy).
# Contém SEGREDOS. Permissão 600, dono root.

# ── Compose ─────────────────────────────────────────────────────────────────
REGISTRY=${REGISTRY}
IMAGE_TAG=${IMAGE_TAG}
DATA_DIR=${DATA_DIR}
COMPOSE_PROFILES=${COMPOSE_PROFILES}

# ── Laravel (comum a api, admin, worker e scheduler) ────────────────────────
APP_ENV=production
APP_DEBUG=false
APP_URL=${APP_URL}
APP_KEY=${APP_KEY_API}
TURNI_ENV=${TURNI_ENV}

# stderr mantém \`docker compose logs\` útil; turni_json escreve o arquivo que o
# Ops Agent leva ao Cloud Logging com jsonPayload estruturado (ADR-008).
LOG_CHANNEL=stack
LOG_STACK=stderr,turni_json
LOG_LEVEL=info
LOG_STDERR_FORMATTER=Monolog\\Formatter\\JsonFormatter

# Atrás do Caddy (que já é o único caminho de entrada): sem confiar no proxy, o
# Laravel gera URL http:// nos e-mails e a detecção de HTTPS falha.
TRUSTED_PROXIES=*

# ── Banco ───────────────────────────────────────────────────────────────────
DB_CONNECTION=${DB_CONNECTION}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_DATABASE=${DB_DATABASE}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}

QUEUE_CONNECTION=database
CACHE_STORE=database

# ── Auth / roteamento entre superfícies ─────────────────────────────────────
# O WebApp chama /api no PRÓPRIO host (Caddy faz o same-origin), então é este o
# domínio stateful do Sanctum.
SANCTUM_STATEFUL_DOMAINS=${WEBAPP_HOST}
BACKOFFICE_URL=https://${ADMIN_HOST}

# ── E-mail transacional (ADR-011) ───────────────────────────────────────────
MAIL_MAILER=${MAIL_MAILER}
MAIL_FROM_ADDRESS=${MAIL_FROM_ADDRESS}
MAIL_FROM_NAME=${MAIL_FROM_NAME}
RESEND_API_KEY=${RESEND_API_KEY}

# ── Pagamento (PDR-017 / ADR-016) ───────────────────────────────────────────
PAGARME_DRIVER=${PAGARME_DRIVER}
PAGARME_BASE_URL=${PAGARME_BASE_URL}
PAGARME_SECRET_KEY=${PAGARME_SECRET_KEY}
PAGARME_WEBHOOK_SECRET=${PAGARME_WEBHOOK_SECRET}
PAGARME_MOCK_PIX_RESULTADO=${PAGARME_MOCK_PIX_RESULTADO}
PAGARME_MOCK_PIX_SLA_SEGUNDOS=${PAGARME_MOCK_PIX_SLA_SEGUNDOS}
PIX_FALHA_CHAVE_KEY=${PIX_FALHA_CHAVE_KEY}

# ── Caddy ───────────────────────────────────────────────────────────────────
ACME_EMAIL=${ACME_EMAIL}
CLOUDFLARE_DNS_TOKEN=${CLOUDFLARE_DNS_TOKEN}
WEBAPP_HOST=${WEBAPP_HOST}
ADMIN_HOST=${ADMIN_HOST}
API_HOST=${API_HOST}
LANDING_HOST=${LANDING_HOST}
EOF

# O Backoffice tem APP_KEY própria (ADR-009 5A: chaves distintas por app). Sobrepõe
# o .env comum via segundo env_file no compose.
cat > "$OUT_ADMIN" <<EOF
# GERADO por scripts/render-env.sh — overrides SÓ do Backoffice.
APP_KEY=${APP_KEY_ADMIN}
EOF

chmod 600 "$OUT" "$OUT_ADMIN"
chown root:root "$OUT" "$OUT_ADMIN" 2>/dev/null || true

echo "-- $OUT e $OUT_ADMIN escritos (600)"
