# Ambiente de homologação do Turni.
# Provisiona: VPC, Cloud SQL, Cloud Run (api + admin), worker (Cloud Run Job — IDR-016),
# Firebase Hosting (webapp), DNS, Secret Manager, Monitoring.
# Recriar do zero: `terraform apply` (ver runbook docs/operacao/runbook-homolog.md).

locals {
  env                = "homolog"
  api_host           = "api.homolog.turni.com.br"
  admin_host         = "admin.homolog.turni.com.br"
  webapp_host        = "app.homolog.turni.com.br"
  landing_host       = "landing.homolog.turni.com.br"
  mail_sender_domain = "mail.homolog.turni.com.br" # remetente Resend (ADR-011 §e)
  mail_from_address  = "no-reply@${local.mail_sender_domain}"
  cloudsql_socket    = "/cloudsql/${module.cloud_sql.connection_name}"
}

# ── APIs GCP necessárias ─────────────────────────────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "dns.googleapis.com",
    "artifactregistry.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "iap.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudscheduler.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ── VPC ──────────────────────────────────────────────────────────────────────
resource "google_compute_network" "main" {
  project                 = var.project_id
  name                    = "turni-${local.env}"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "main" {
  project       = var.project_id
  region        = var.region
  name          = "turni-${local.env}-${var.region}"
  network       = google_compute_network.main.self_link
  ip_cidr_range = "10.1.0.0/24"
}

# Private Service Connection para Cloud SQL sem IP público
resource "google_compute_global_address" "private_ip_range" {
  project       = var.project_id
  name          = "turni-${local.env}-psc-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# ── IAM + WIF ────────────────────────────────────────────────────────────────
module "iam" {
  source      = "../../modules/iam"
  project_id  = var.project_id
  github_repo = var.github_repo
  depends_on  = [google_project_service.apis]
}

# ── Artifact Registry ─────────────────────────────────────────────────────────
module "artifact_registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  region     = var.region
  depends_on = [google_project_service.apis]
}

# ── Segredos ──────────────────────────────────────────────────────────────────
module "secrets" {
  source         = "../../modules/secrets"
  project_id     = var.project_id
  env            = local.env
  app_key_api    = var.app_key_api
  app_key_admin  = var.app_key_admin
  db_password    = var.db_password
  resend_api_key = var.resend_api_key
  depends_on     = [google_project_service.apis]
}

# ── Cloud SQL ─────────────────────────────────────────────────────────────────
module "cloud_sql" {
  source      = "../../modules/cloud-sql"
  project_id  = var.project_id
  region      = var.region
  env         = local.env
  db_password = var.db_password
  vpc_network = google_compute_network.main.self_link
  depends_on  = [google_service_networking_connection.private_vpc_connection]
}

# ── Cloud Run: API (público) ──────────────────────────────────────────────────
module "cloud_run_api" {
  source                   = "../../modules/cloud-run"
  project_id               = var.project_id
  region                   = var.region
  app                      = "api"
  env                      = local.env
  image                    = var.api_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  ingress                  = "INGRESS_TRAFFIC_ALL"
  allow_unauthenticated    = true
  # Direct VPC egress: Cloud SQL é IP privado; sem isto o socket dá timeout (STORY-016).
  vpc_network    = google_compute_network.main.name
  vpc_subnetwork = google_compute_subnetwork.main.name

  env_vars = {
    APP_ENV          = "production"
    APP_DEBUG        = "false"
    APP_URL          = "https://${local.webapp_host}"
    LOG_CHANNEL      = "stderr"
    DB_CONNECTION    = "pgsql"
    DB_SOCKET        = local.cloudsql_socket
    DB_DATABASE      = "turni"
    DB_USERNAME      = "turni"
    QUEUE_CONNECTION = "database"
    SESSION_DRIVER   = "database"
    # E-mail transacional (ADR-011 §c): provedor Resend em homolog; chave via Secret
    # Manager (secret_env_vars). Remetente no subdomínio dedicado mail.homolog.
    MAIL_MAILER       = "resend"
    MAIL_FROM_ADDRESS = local.mail_from_address
    MAIL_FROM_NAME    = "Turni"
    # Sanctum SPA: o WebApp é servido em app.homolog e chama /api no MESMO domínio
    # (Firebase rewrite → este Cloud Run). Marca o domínio como stateful p/ usar a
    # sessão por cookie. BACKOFFICE_URL alimenta o banner "Ir para o Backoffice".
    SANCTUM_STATEFUL_DOMAINS = local.webapp_host
    BACKOFFICE_URL           = "https://turni-admin-homolog-dnj2tcr2xa-rj.a.run.app"
  }

  secret_env_vars = {
    APP_KEY        = { secret = module.secrets.app_key_api_secret_id, version = "latest" }
    DB_PASSWORD    = { secret = module.secrets.db_password_secret_id, version = "latest" }
    RESEND_API_KEY = { secret = module.secrets.resend_api_key_secret_id, version = "latest" }
  }

  depends_on = [module.cloud_sql, module.secrets]
}

# ── Cloud Run: Admin (homolog: público para E2E; prod: interno + IAP — IDR-003) ─
module "cloud_run_admin" {
  source                   = "../../modules/cloud-run"
  project_id               = var.project_id
  region                   = var.region
  app                      = "admin"
  env                      = local.env
  image                    = var.admin_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  ingress                  = "INGRESS_TRAFFIC_ALL"
  allow_unauthenticated    = true
  # Direct VPC egress: o admin também conecta ao Cloud SQL de IP privado via socket
  # (DB_SOCKET); sem isto o socket dá timeout (IDR-007). Estava aplicado ao vivo mas
  # ausente do módulo — reconciliado durante a STORY-034 para zerar o drift (CA-4).
  vpc_network    = google_compute_network.main.name
  vpc_subnetwork = google_compute_subnetwork.main.name

  env_vars = {
    APP_ENV        = "production"
    APP_DEBUG      = "false"
    LOG_CHANNEL    = "stderr"
    DB_CONNECTION  = "pgsql"
    DB_SOCKET      = local.cloudsql_socket
    DB_DATABASE    = "turni"
    DB_USERNAME    = "turni"
    SESSION_DRIVER = "cookie"
  }

  secret_env_vars = {
    APP_KEY     = { secret = module.secrets.app_key_admin_secret_id, version = "latest" }
    DB_PASSWORD = { secret = module.secrets.db_password_secret_id, version = "latest" }
  }

  depends_on = [module.cloud_sql, module.secrets]
}

# ── Worker (Cloud Run Job + Cloud Scheduler — IDR-016) ────────────────────────
# Substitui o GCE worker-vm (que nunca funcionou em homolog: 5 gaps de infra, ver
# IDR-016). Cloud Scheduler dispara o Job a cada 1 min; o Job roda
# `queue:work --stop-when-empty` e sai quando a fila esvazia. Mesma fiação do
# cloud_run_api (Direct VPC egress + Cloud SQL socket + secret_env_vars).
# Reversão: trocar este bloco por `module "worker"` (worker-vm, mantido desabilitado).
module "worker_job" {
  source                   = "../../modules/worker-job"
  project_id               = var.project_id
  region                   = var.region
  env                      = local.env
  image                    = var.api_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  vpc_network              = google_compute_network.main.name
  vpc_subnetwork           = google_compute_subnetwork.main.name

  # Paridade de ambiente com o cloud_run_api (o worker roda o mesmo código).
  env_vars = {
    APP_ENV           = "production"
    APP_DEBUG         = "false"
    APP_URL           = "https://${local.webapp_host}"
    LOG_CHANNEL       = "stderr"
    DB_CONNECTION     = "pgsql"
    DB_SOCKET         = local.cloudsql_socket
    DB_DATABASE       = "turni"
    DB_USERNAME       = "turni"
    QUEUE_CONNECTION  = "database"
    MAIL_MAILER       = "resend"
    MAIL_FROM_ADDRESS = local.mail_from_address
    MAIL_FROM_NAME    = "Turni"
  }

  secret_env_vars = {
    APP_KEY        = { secret = module.secrets.app_key_api_secret_id, version = "latest" }
    DB_PASSWORD    = { secret = module.secrets.db_password_secret_id, version = "latest" }
    RESEND_API_KEY = { secret = module.secrets.resend_api_key_secret_id, version = "latest" }
  }

  depends_on = [module.cloud_sql, module.secrets]
}

# ── Firebase Hosting (WebApp Flutter + landing institucional) ────────────────
# Site principal: WebApp. Site adicional: landing (ADR-012 — site único por ambiente
# que serve "Em breve" no apex, landing AS IS no path secreto, robots.txt e 404).
module "firebase" {
  source        = "../../modules/firebase"
  project_id    = var.project_id
  env           = local.env
  custom_domain = local.webapp_host
  additional_sites = {
    landing = {
      site_id       = "turni-landing-${local.env}" # turni-landing-homolog
      custom_domain = local.landing_host           # landing.homolog.turni.com.br
    }
  }
  depends_on = [google_project_service.apis]
}

# ── Agendamento liga/desliga do Cloud SQL (economia de custo) ─────────────────
# Desliga: seg–sex 22h BRT; sáb+dom ficam desligados.
# Liga: seg–sex 06h BRT.
module "sql_scheduler" {
  source        = "../../modules/sql-scheduler"
  project_id    = var.project_id
  region        = var.region
  env           = local.env
  instance_name = module.cloud_sql.instance_name
  depends_on    = [google_project_service.apis, module.cloud_sql]
}

# ── DNS (Cloud DNS) ──────────────────────────────────────────────────────────
# Fase 1 (feita): zona criada, NS configurados no registro.br.
# Fase 2 (esta): CNAME webapp → Firebase (app.homolog.turni.com.br).
# API: Cloud Run domain mapping não é suportado em southamerica-east1.
#      Em homolog: acesso via URL direta do Cloud Run.
#      Em prod: provisionar HTTPS LB + Serverless NEG.
module "dns" {
  source               = "../../modules/dns"
  project_id           = var.project_id
  create_zone          = true
  dns_zone_name        = "turni-com-br"
  webapp_subdomain     = local.webapp_host
  webapp_cname_target  = module.firebase.cname_target
  landing_subdomain    = local.landing_host
  landing_cname_target = module.firebase.additional_cname_targets["landing"]

  # Domínio remetente de e-mail (Resend — ADR-011 §e / STORY-021). Região sa-east-1
  # (default do módulo). DKIM é a chave pública gerada pelo Resend (dado público de DNS).
  mail_sender_domain = local.mail_sender_domain
  mail_dkim_value    = var.mail_dkim_value

  depends_on = [google_project_service.apis, module.firebase]
}

# ── Monitoramento (ADR-008) ───────────────────────────────────────────────────
module "monitoring" {
  source      = "../../modules/monitoring"
  project_id  = var.project_id
  env         = local.env
  alert_email = var.alert_email
  api_host    = local.api_host
  admin_host  = local.admin_host
  webapp_host = local.webapp_host
  depends_on  = [google_project_service.apis]
}
