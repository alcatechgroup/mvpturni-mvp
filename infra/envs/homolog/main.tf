# Ambiente de HOMOLOGAÇÃO do Turni — uma VPS no projeto FoodHub (ADR-021).
#
# Recriar do zero: `terraform apply` aqui + o pipeline publicando a última tag.
# Runbook completo: docs/operacao/runbook-vps.md
#
# Este arquivo é deliberadamente curto: toda a estrutura vive no módulo
# `environment`, e o que muda entre homolog/staging/prod são só os valores abaixo.

# Recursos compartilhados (registry e identidade do CI) vêm do state `shared`, não
# de valores copiados — assim renomear a SA do CI não exige editar três ambientes.
data "terraform_remote_state" "shared" {
  backend = "gcs"
  config = {
    bucket = "turni-tfstate-foodhub-87e0c"
    prefix = "shared"
  }
}

module "homolog" {
  source = "../../modules/environment"

  project_id = var.project_id
  env        = "homolog"
  region     = var.region
  zone       = var.zone

  # Ambiente de NEGÓCIO: liga o banner "Ambiente de teste — pagamentos simulados"
  # no Backoffice (STORY-075 / PDR-017).
  business_env = "homolog"

  # ── Rede e máquina ─────────────────────────────────────────────────────────
  subnet_cidr  = "10.10.0.0/24"
  machine_type = "e2-small"
  # Homolog não precisa do backbone premium: o tráfego chega pela borda da
  # Cloudflare de qualquer forma, e STANDARD corta alguns dólares por mês.
  network_tier      = "STANDARD"
  data_disk_size_gb = 20

  # ── Hosts ACHATADOS (Universal SSL cobre só um nível — ADR-021 §c) ─────────
  hosts = {
    webapp  = "app-homolog.turni.com.br"
    admin   = "admin-homolog.turni.com.br"
    api     = "api-homolog.turni.com.br"
    landing = "homolog.turni.com.br"
  }

  dns_zone_id      = var.cloudflare_zone_id
  mail_sender_host = "mail-homolog"
  mail_dkim_value  = var.mail_dkim_value
  acme_email       = var.alert_email

  # ── Imagens e deploy ───────────────────────────────────────────────────────
  registry_url       = data.terraform_remote_state.shared.outputs.registry_url
  runtime_source_dir = "${path.module}/../../vps"
  deployer_members   = [data.terraform_remote_state.shared.outputs.ci_service_account_member]

  # ── Fake de pagamento: só aqui, nunca em prod (PDR-017 / ADR-016 d) ────────
  enable_payment_fake           = true
  pagarme_mock_pix_resultado    = var.pagarme_mock_pix_resultado
  pagarme_mock_pix_sla_segundos = var.pagarme_mock_pix_sla_segundos

  # ── Observabilidade ────────────────────────────────────────────────────────
  alert_email          = var.alert_email
  enable_uptime_checks = var.enable_uptime_checks

  # ── Segredos (valores fora do git — ver terraform.tfvars.example) ──────────
  secrets = {
    "app-key-api"            = var.app_key_api
    "app-key-admin"          = var.app_key_admin
    "db-password"            = var.db_password
    "resend-api-key"         = var.resend_api_key
    "cloudflare-dns-token"   = var.cloudflare_token
    "pagarme-secret-key"     = var.pagarme_secret_key
    "pagarme-webhook-secret" = var.pagarme_webhook_secret
    "pix-falha-chave-key"    = var.pix_falha_chave_key
  }
}
