# Ambiente de PRODUÇÃO do Turni — uma VPS no projeto FoodHub (ADR-021).
#
# ESCRITO, AINDA NÃO APLICADO. Sobe quando o gate de produção entrar em uso.
#
# Diferenças deliberadas em relação a homolog/staging:
#   • fake de pagamento DESLIGADO (`enable_payment_fake = false`) — em produção só
#     entra PSP real; a ausência do bloco é o que garante isso;
#   • `business_env = "production"` — a AUSÊNCIA do valor "homolog" é o que desliga
#     o banner "Ambiente de teste" no Backoffice e no WebApp (STORY-075);
#   • máquina e disco maiores, `network_tier = PREMIUM` e alertas de uptime ligados;
#   • landing no APEX (turni.com.br) — o site institucional é a porta de entrada.

data "terraform_remote_state" "shared" {
  backend = "gcs"
  config = {
    bucket = "turni-tfstate-foodhub-87e0c"
    prefix = "shared"
  }
}

module "prod" {
  source = "../../modules/environment"

  project_id = var.project_id
  env        = "prod"
  region     = var.region
  zone       = var.zone

  business_env = "production"

  subnet_cidr       = "10.30.0.0/24"
  machine_type      = var.machine_type
  network_tier      = "PREMIUM"
  data_disk_size_gb = var.data_disk_size_gb

  # Em produção os subdomínios não têm sufixo de ambiente, e a landing fica no apex.
  hosts = {
    webapp  = "app.turni.com.br"
    admin   = "admin.turni.com.br"
    api     = "api.turni.com.br"
    landing = "turni.com.br"
  }

  dns_zone_id      = var.cloudflare_zone_id
  mail_sender_host = "mail"
  mail_dkim_value  = var.mail_dkim_value
  acme_email       = var.alert_email

  registry_url       = data.terraform_remote_state.shared.outputs.registry_url
  runtime_source_dir = "${path.module}/../../vps"
  deployer_members   = [data.terraform_remote_state.shared.outputs.ci_service_account_member]

  # Sem fake de pagamento. Não reintroduzir "só para testar em produção".
  enable_payment_fake = false

  alert_email           = var.alert_email
  enable_uptime_checks  = true
  backup_retention_days = 90

  secrets = {
    "app-key-api"          = var.app_key_api
    "app-key-admin"        = var.app_key_admin
    "db-password"          = var.db_password
    "resend-api-key"       = var.resend_api_key
    "cloudflare-dns-token" = var.cloudflare_token
    "pix-falha-chave-key"  = var.pix_falha_chave_key
  }
}
