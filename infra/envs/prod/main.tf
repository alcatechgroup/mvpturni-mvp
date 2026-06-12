# Ambiente de PRODUÇÃO do Turni.
# SCAFFOLDED — idêntico ao homolog em estrutura, diferente nos valores.
# NÃO aplicar antes do EPIC-006 (ADR-004 / epic.md).
# Subdomínios sem "homolog.": app.turni.com.br, admin.turni.com.br, api.turni.com.br.

locals {
  env             = "prod"
  api_host        = "api.turni.com.br"
  admin_host      = "admin.turni.com.br"
  webapp_host     = "app.turni.com.br"
  apex_host       = "turni.com.br"
  www_host        = "www.turni.com.br"
  cloudsql_socket = "/cloudsql/${module.cloud_sql.connection_name}"

  # Sites Firebase da landing prod — só materializados no go-public (landing_prod_enabled).
  landing_prod_sites = var.landing_prod_enabled ? {
    landing      = { site_id = "turni-landing-prod", custom_domain = local.apex_host }
    www_redirect = { site_id = "turni-redirect-prod", custom_domain = local.www_host }
  } : {}
}

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
  ip_cidr_range = "10.2.0.0/24"
}

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

module "iam" {
  source      = "../../modules/iam"
  project_id  = var.project_id
  github_repo = var.github_repo
  depends_on  = [google_project_service.apis]
}

module "artifact_registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  region     = var.region
  depends_on = [google_project_service.apis]
}

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

module "cloud_sql" {
  source      = "../../modules/cloud-sql"
  project_id  = var.project_id
  region      = var.region
  env         = local.env
  db_password = var.db_password
  db_tier     = "db-g1-small" # produção: tier maior (não cobra enquanto STOPPED)
  # PROD PARADO: o Cloud SQL NÃO pode ser CRIADO já parado (a API rejeita
  # activation_policy=NEVER no create). Cria-se RUNNABLE e o stop é um patch
  # pós-apply: `gcloud sql instances patch turni-prod --activation-policy=NEVER`.
  # O módulo tem ignore_changes em activation_policy, então o TF não reverte o stop
  # (nem o start no go-live). Mantém-se ALWAYS aqui só para o momento do create.
  activation_policy = "ALWAYS"
  vpc_network       = google_compute_network.main.self_link
  depends_on        = [google_service_networking_connection.private_vpc_connection]
}

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
  # PROD PARADO: 0 = sem custo enquanto parado. No go-live (prod_live_enabled=true)
  # vira 1 (sem cold start — ADR-004 Negativas).
  min_instances = var.prod_live_enabled ? 1 : 0

  env_vars = {
    APP_ENV          = "production"
    APP_DEBUG        = "false"
    LOG_CHANNEL      = "stderr"
    DB_CONNECTION    = "pgsql"
    DB_SOCKET        = local.cloudsql_socket
    DB_DATABASE      = "turni"
    DB_USERNAME      = "turni"
    QUEUE_CONNECTION = "database"
  }

  secret_env_vars = {
    APP_KEY     = { secret = module.secrets.app_key_api_secret_id, version = "latest" }
    DB_PASSWORD = { secret = module.secrets.db_password_secret_id, version = "latest" }
  }

  depends_on = [module.cloud_sql, module.secrets]
}

module "cloud_run_admin" {
  source                   = "../../modules/cloud-run"
  project_id               = var.project_id
  region                   = var.region
  app                      = "admin"
  env                      = local.env
  image                    = var.admin_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  ingress                  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  allow_unauthenticated    = false
  min_instances            = var.prod_live_enabled ? 1 : 0 # PROD PARADO

  env_vars = {
    APP_ENV   = "production"
    APP_DEBUG = "false"
    # APP_URL = WebApp: o e-mail de aprovação (admin ApprovalService) monta o CTA com
    # config('app.webapp_url', config('app.url')); sem APP_URL ia http://localhost no
    # e-mail. Backoffice é Livewire (URLs relativas) — não depende de APP_URL própria.
    APP_URL       = "https://${local.webapp_host}"
    LOG_CHANNEL   = "stderr"
    DB_CONNECTION = "pgsql"
    DB_SOCKET     = local.cloudsql_socket
    DB_DATABASE   = "turni"
    DB_USERNAME   = "turni"
  }

  secret_env_vars = {
    APP_KEY     = { secret = module.secrets.app_key_admin_secret_id, version = "latest" }
    DB_PASSWORD = { secret = module.secrets.db_password_secret_id, version = "latest" }
  }

  depends_on = [module.cloud_sql, module.secrets]
}

# ── Worker da fila + Scheduler do Laravel (Cloud Run Jobs — IDR-016/STORY-073) ─
# O scaffold original usava worker-vm, superado pela IDR-016 (Cloud Run Job +
# Cloud Scheduler) em homolog — e a chamada nem validava mais contra o módulo
# atual. Reconciliado na STORY-073 para espelhar homolog: worker (queue:work) e
# scheduler (schedule:run) como Jobs SEPARADOS — kill-switch independente.
# GATED como todo este ambiente: prod só é aplicado com aprovação manual (header
# deste arquivo / EPIC-006); o deploy de prod NÃO é requisito da STORY-073 (CA-2).
# Env mínima em paridade com o cloud_run_api de prod (sem MAIL/PAGARME — esses
# entram aqui junto com o go-live, quando entrarem no cloud_run_api).
locals {
  job_env_vars = {
    APP_ENV              = "production"
    APP_DEBUG            = "false"
    LOG_CHANNEL          = "stderr"
    DB_CONNECTION        = "pgsql"
    DB_SOCKET            = local.cloudsql_socket
    DB_DATABASE          = "turni"
    DB_USERNAME          = "turni"
    QUEUE_CONNECTION     = "database"
    LOG_STDERR_FORMATTER = "Monolog\\Formatter\\JsonFormatter"
  }

  job_secret_env_vars = {
    APP_KEY     = { secret = module.secrets.app_key_api_secret_id, version = "latest" }
    DB_PASSWORD = { secret = module.secrets.db_password_secret_id, version = "latest" }
  }
}

module "worker_job" {
  source                   = "../../modules/worker-job"
  scheduler_enabled        = var.prod_live_enabled # PROD PARADO: Job existe, trigger NÃO é criado
  project_id               = var.project_id
  region                   = var.region
  env                      = local.env
  image                    = var.api_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  vpc_network              = google_compute_network.main.name
  vpc_subnetwork           = google_compute_subnetwork.main.name

  env_vars        = local.job_env_vars
  secret_env_vars = local.job_secret_env_vars

  depends_on = [module.cloud_sql, module.secrets]
}

# Invoca `php artisan schedule:run` a cada 1 min, ativando os Schedule::command()
# de routes/console.php (auto-retirada PDR-009, lembretes, sweeper de e-mail,
# no-show). Espelho do scheduler_job de homolog (módulo worker-job parametrizado).
module "scheduler_job" {
  source                   = "../../modules/worker-job"
  scheduler_enabled        = var.prod_live_enabled # PROD PARADO: trigger NÃO é criado
  project_id               = var.project_id
  region                   = var.region
  env                      = local.env
  name                     = "scheduler"
  sa_account_short         = "schd"
  command                  = ["php", "artisan", "schedule:run"]
  image                    = var.api_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  vpc_network              = google_compute_network.main.name
  vpc_subnetwork           = google_compute_subnetwork.main.name

  env_vars        = local.job_env_vars
  secret_env_vars = local.job_secret_env_vars

  depends_on = [module.cloud_sql, module.secrets]
}

# PROD PARADO: Firebase Hosting do prod só sobe no go-live (prod_live_enabled) ou no
# go-public da landing (landing_prod_enabled). Enquanto parado não há WebApp/landing de
# prod servindo, então não criamos os sites — também evita o resíduo de Hosting do
# projeto turni-prod recuperado (channel `live` órfão da encarnação anterior), que será
# tratado no go-live.
module "firebase" {
  count            = (var.prod_live_enabled || var.landing_prod_enabled) ? 1 : 0
  source           = "../../modules/firebase"
  project_id       = var.project_id
  env              = local.env
  additional_sites = local.landing_prod_sites # vazio até go-public (ADR-012 §8)
  depends_on       = [google_project_service.apis]
}

# ── DNS apex — turni.com.br vive no turni-prod (modelo de 3 projetos independentes) ─
# Esta é a zona RAIZ do domínio: o registro.br delega turni.com.br para os nameservers
# desta zona (output dns_name_servers). Ela publica os NS de DELEGAÇÃO dos subdomínios
# homolog.turni.com.br (turni-homol) e stage.turni.com.br (turni-stage) — preencher
# var.delegations com os outputs `dns_name_servers` daqueles envs. Os CNAMEs de app/api
# de prod e o apex/www da landing entram no go-live (módulo dns_landing, gated abaixo).
module "dns" {
  source        = "../../modules/dns"
  project_id    = var.project_id
  create_zone   = true
  dns_zone_name = "turni-com-br"
  # zone_dns_name usa o default "turni.com.br." (apex)
  delegations = var.delegations
  depends_on  = [google_project_service.apis]
}

# ── DNS da landing prod (apex A/AAAA + www redirect) ──────────────────────────
# Zona turni-com-br já existe (criada em homolog com create_zone=true). Aqui só os
# registros do apex e www, gated pelo go-public. Com landing_prod_enabled=false o
# count=0 → terraform plan em prod mostra 0 changes referentes à landing (CA-9).
module "dns_landing" {
  count             = var.landing_prod_enabled ? 1 : 0
  source            = "../../modules/dns"
  project_id        = var.project_id
  create_zone       = false
  dns_zone_name     = "turni-com-br"
  apex_domain       = local.apex_host
  apex_a_records    = var.firebase_apex_a_records
  apex_aaaa_records = var.firebase_apex_aaaa_records
  www_subdomain     = local.www_host
  www_cname_target  = module.firebase[0].additional_cname_targets["www_redirect"]
  depends_on        = [google_project_service.apis, module.firebase, module.dns]
}

module "monitoring" {
  # PROD PARADO: sem uptime checks/alertas enquanto parado (uptime contra api parada
  # dispararia "indisponível" sem parar). Ligado no go-live (prod_live_enabled=true).
  count       = var.prod_live_enabled ? 1 : 0
  source      = "../../modules/monitoring"
  project_id  = var.project_id
  env         = local.env
  alert_email = var.alert_email
  api_host    = local.api_host
  admin_host  = local.admin_host
  webapp_host = local.webapp_host
  depends_on  = [google_project_service.apis]
}
