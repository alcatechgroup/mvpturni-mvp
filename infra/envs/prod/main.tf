# Ambiente de PRODUÇÃO do Turni.
# SCAFFOLDED — idêntico ao homolog em estrutura, diferente nos valores.
# NÃO aplicar antes do EPIC-006 (ADR-004 / epic.md).
# Subdomínios sem "homolog.": app.turni.com.br, admin.turni.com.br, api.turni.com.br.

locals {
  env         = "prod"
  api_host    = "api.turni.com.br"
  admin_host  = "admin.turni.com.br"
  webapp_host = "app.turni.com.br"
  cloudsql_socket = "/cloudsql/${module.cloud_sql.connection_name}"
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
  source        = "../../modules/secrets"
  project_id    = var.project_id
  env           = local.env
  app_key_api   = var.app_key_api
  app_key_admin = var.app_key_admin
  db_password   = var.db_password
  depends_on    = [google_project_service.apis]
}

module "cloud_sql" {
  source      = "../../modules/cloud-sql"
  project_id  = var.project_id
  region      = var.region
  env         = local.env
  db_password = var.db_password
  db_tier     = "db-g1-small"  # produção: tier maior
  vpc_network = google_compute_network.main.self_link
  depends_on  = [google_service_networking_connection.private_vpc_connection]
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
  min_instances            = 1  # prod: sem cold start (ADR-004 Negativas)

  env_vars = {
    APP_ENV       = "production"
    APP_DEBUG     = "false"
    LOG_CHANNEL   = "stderr"
    DB_CONNECTION = "pgsql"
    DB_SOCKET     = local.cloudsql_socket
    DB_DATABASE   = "turni"
    DB_USERNAME   = "turni"
    QUEUE_CONNECTION = "database"
  }

  secret_env_vars = {
    APP_KEY     = { secret = module.secrets.app_key_api_secret_id,  version = "latest" }
    DB_PASSWORD = { secret = module.secrets.db_password_secret_id,  version = "latest" }
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
  min_instances            = 1

  env_vars = {
    APP_ENV       = "production"
    APP_DEBUG     = "false"
    LOG_CHANNEL   = "stderr"
    DB_CONNECTION = "pgsql"
    DB_SOCKET     = local.cloudsql_socket
    DB_DATABASE   = "turni"
    DB_USERNAME   = "turni"
  }

  secret_env_vars = {
    APP_KEY     = { secret = module.secrets.app_key_admin_secret_id, version = "latest" }
    DB_PASSWORD = { secret = module.secrets.db_password_secret_id,   version = "latest" }
  }

  depends_on = [module.cloud_sql, module.secrets]
}

module "worker" {
  source                    = "../../modules/worker-vm"
  project_id                = var.project_id
  region                    = var.region
  env                       = local.env
  image                     = var.api_image
  service_account_email     = module.iam.apps_service_account_email
  cloudsql_connection_name  = module.cloud_sql.connection_name
  vpc_network               = google_compute_network.main.self_link
  subnetwork                = google_compute_subnetwork.main.self_link
  depends_on                = [module.cloud_sql]
}

module "firebase" {
  source     = "../../modules/firebase"
  project_id = var.project_id
  env        = local.env
  depends_on = [google_project_service.apis]
}

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
