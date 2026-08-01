# Ambiente de STAGING do Turni — uma VPS no projeto FoodHub (ADR-021).
#
# ESCRITO, AINDA NÃO APLICADO. Existe agora para que a estrutura multi-ambiente
# nasça junto (exigência herdada do EPIC-000) e para que homolog não vire o único
# ambiente que alguém sabe recriar. Aplicar quando o fluxo de promoção
# homolog → staging → prod entrar em uso.
#
# Diferenças em relação a homolog: subnet própria, hosts próprios e o fake de
# pagamento ligado (staging ainda é ambiente de teste).

data "terraform_remote_state" "shared" {
  backend = "gcs"
  config = {
    bucket = "turni-tfstate-foodhub-87e0c"
    prefix = "shared"
  }
}

module "staging" {
  source = "../../modules/environment"

  project_id = var.project_id
  env        = "staging"
  region     = var.region
  zone       = var.zone

  # `homolog` é o CONTRATO do banner "Ambiente de teste — pagamentos simulados"
  # (match exato no admin e no WebApp — STORY-075). Staging também é ambiente de
  # teste com gateway fake, então precisa do banner. Trocar para "staging" só
  # depois de ensinar as duas apps a reconhecerem o valor.
  business_env = "homolog"

  subnet_cidr       = "10.20.0.0/24"
  machine_type      = "e2-small"
  network_tier      = "STANDARD"
  data_disk_size_gb = 20

  hosts = {
    webapp  = "app-staging.turni.com.br"
    admin   = "admin-staging.turni.com.br"
    api     = "api-staging.turni.com.br"
    landing = "staging.turni.com.br"
  }

  dns_zone_id      = var.cloudflare_zone_id
  mail_sender_host = "mail-staging"
  mail_dkim_value  = var.mail_dkim_value
  acme_email       = var.alert_email

  registry_url       = data.terraform_remote_state.shared.outputs.registry_url
  runtime_source_dir = "${path.module}/../../vps"
  deployer_members   = [data.terraform_remote_state.shared.outputs.ci_service_account_member]

  enable_payment_fake           = true
  pagarme_mock_pix_resultado    = var.pagarme_mock_pix_resultado
  pagarme_mock_pix_sla_segundos = var.pagarme_mock_pix_sla_segundos

  alert_email          = var.alert_email
  enable_uptime_checks = var.enable_uptime_checks

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
