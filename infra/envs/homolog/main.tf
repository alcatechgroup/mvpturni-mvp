# Ambiente de homologação do Turni.
# Provisiona: VPC, Cloud SQL, Cloud Run (api + admin), GCE worker,
# Firebase Hosting (webapp), DNS, Secret Manager, Monitoring.
# Recriar do zero: `terraform apply` (ver runbook docs/operacao/runbook-homolog.md).

locals {
  env             = "homolog"
  api_host        = "api.homolog.turni.com.br"
  admin_host      = "admin.homolog.turni.com.br"
  webapp_host     = "app.homolog.turni.com.br"
  cloudsql_socket = "/cloudsql/${module.cloud_sql.connection_name}"
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
  source        = "../../modules/secrets"
  project_id    = var.project_id
  env           = local.env
  app_key_api   = var.app_key_api
  app_key_admin = var.app_key_admin
  db_password   = var.db_password
  depends_on    = [google_project_service.apis]
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

# ── Cloud Run: Admin (ingress interno + IAP) ──────────────────────────────────
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

# ── Worker (GCE e2-micro) ─────────────────────────────────────────────────────
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

# ── Firebase Hosting (WebApp Flutter) ────────────────────────────────────────
module "firebase" {
  source     = "../../modules/firebase"
  project_id = var.project_id
  env        = local.env
  depends_on = [google_project_service.apis]
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
