# ─────────────────────────────────────────────────────────────────────────────
# Ambiente STAGE co-localizado no projeto turni-homol (unificação homol+stage).
#
# REUSA do homol (sem recriar): o projeto, as APIs habilitadas, o VPC
# (google_compute_network.main), o Cloud SQL (module.cloud_sql — UM instance), o IAM/WIF
# (module.iam), o Artifact Registry (module.artifact_registry) e o sql-scheduler (uma
# agenda só liga/desliga o instance compartilhado).
#
# ISOLAMENTO de dados: database + user dedicados (turni_stage) no MESMO instance; o user
# turni_stage só tem grant no database turni_stage (homol segue em db `turni`/user `turni`).
# ISOLAMENTO de rede: subnet própria 10.3.0.0/24 no MESMO VPC (o peering do SQL é por-VPC).
# ─────────────────────────────────────────────────────────────────────────────

locals {
  stage_env                = "stage"
  stage_api_host           = "api.stage.turni.com.br"
  stage_admin_host         = "admin.stage.turni.com.br"
  stage_webapp_host        = "app.stage.turni.com.br"
  stage_landing_host       = "landing.stage.turni.com.br"
  stage_mail_sender_domain = "mail.stage.turni.com.br"
  stage_mail_from_address  = "no-reply@${local.stage_mail_sender_domain}"
  # Mesmo instance/socket do homol (banco compartilhado): só DB_DATABASE/DB_USERNAME mudam.
  # local.cloudsql_socket (main.tf) = /cloudsql/${module.cloud_sql.connection_name}
}

# ── Subnet de stage no VPC compartilhado ─────────────────────────────────────
resource "google_compute_subnetwork" "stage" {
  project       = var.project_id
  region        = var.region
  name          = "turni-stage-${var.region}"
  network       = google_compute_network.main.self_link
  ip_cidr_range = "10.3.0.0/24"
}

# ── Database + user de stage no instance compartilhado ───────────────────────
resource "google_sql_database" "stage" {
  project  = var.project_id
  instance = module.cloud_sql.instance_name
  name     = "turni_stage"
}

resource "google_sql_user" "stage" {
  project  = var.project_id
  instance = module.cloud_sql.instance_name
  name     = "turni_stage"
  password = var.db_password_stage
}

# ── Segredos de stage (turni-stage-*) ────────────────────────────────────────
module "secrets_stage" {
  source         = "../../modules/secrets"
  project_id     = var.project_id
  env            = local.stage_env
  app_key_api    = var.app_key_api_stage
  app_key_admin  = var.app_key_admin_stage
  db_password    = var.db_password_stage
  resend_api_key = var.resend_api_key_stage
  depends_on     = [google_project_service.apis]
}

# ── Cloud Run: API de stage (público) ────────────────────────────────────────
module "cloud_run_api_stage" {
  source                   = "../../modules/cloud-run"
  project_id               = var.project_id
  region                   = var.region
  app                      = "api"
  env                      = local.stage_env
  image                    = var.api_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  ingress                  = "INGRESS_TRAFFIC_ALL"
  allow_unauthenticated    = true
  vpc_network              = google_compute_network.main.name
  vpc_subnetwork           = google_compute_subnetwork.stage.name

  env_vars = {
    APP_ENV                  = "production"
    APP_DEBUG                = "false"
    APP_URL                  = "https://${local.stage_webapp_host}"
    LOG_CHANNEL              = "stderr"
    DB_CONNECTION            = "pgsql"
    DB_SOCKET                = local.cloudsql_socket
    DB_DATABASE              = "turni_stage"
    DB_USERNAME              = "turni_stage"
    QUEUE_CONNECTION         = "database"
    SESSION_DRIVER           = "database"
    SESSION_COOKIE           = "__session"
    MAIL_MAILER              = "resend"
    MAIL_FROM_ADDRESS        = local.stage_mail_from_address
    MAIL_FROM_NAME           = "Turni"
    SANCTUM_STATEFUL_DOMAINS = local.stage_webapp_host
    BACKOFFICE_URL           = module.cloud_run_admin_stage.service_url
    PAGARME_DRIVER           = "mock"
    PAGARME_BASE_URL         = google_cloud_run_v2_service.pagarme_mock_stage.uri
  }

  secret_env_vars = {
    APP_KEY                = { secret = module.secrets_stage.app_key_api_secret_id, version = "latest" }
    DB_PASSWORD            = { secret = module.secrets_stage.db_password_secret_id, version = "latest" }
    RESEND_API_KEY         = { secret = module.secrets_stage.resend_api_key_secret_id, version = "latest" }
    PAGARME_SECRET_KEY     = { secret = google_secret_manager_secret.pagarme_secret_key_stage.secret_id, version = "latest" }
    PAGARME_WEBHOOK_SECRET = { secret = google_secret_manager_secret.pagarme_webhook_secret_stage.secret_id, version = "latest" }
    PIX_FALHA_CHAVE_KEY    = { secret = google_secret_manager_secret.pix_falha_chave_key_stage.secret_id, version = "latest" }
  }

  depends_on = [module.cloud_sql, module.secrets_stage, google_sql_user.stage]
}

# ── Cloud Run: Admin de stage (público para E2E) ─────────────────────────────
module "cloud_run_admin_stage" {
  source                   = "../../modules/cloud-run"
  project_id               = var.project_id
  region                   = var.region
  app                      = "admin"
  env                      = local.stage_env
  image                    = var.admin_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  ingress                  = "INGRESS_TRAFFIC_ALL"
  allow_unauthenticated    = true
  vpc_network              = google_compute_network.main.name
  vpc_subnetwork           = google_compute_subnetwork.stage.name

  env_vars = {
    APP_ENV        = "production"
    APP_DEBUG      = "false"
    APP_URL        = "https://${local.stage_webapp_host}"
    LOG_CHANNEL    = "stderr"
    DB_CONNECTION  = "pgsql"
    DB_SOCKET      = local.cloudsql_socket
    DB_DATABASE    = "turni_stage"
    DB_USERNAME    = "turni_stage"
    SESSION_DRIVER = "cookie"
    TURNI_ENV      = "stage"
  }

  secret_env_vars = {
    APP_KEY             = { secret = module.secrets_stage.app_key_admin_secret_id, version = "latest" }
    PIX_FALHA_CHAVE_KEY = { secret = google_secret_manager_secret.pix_falha_chave_key_stage.secret_id, version = "latest" }
    DB_PASSWORD         = { secret = module.secrets_stage.db_password_secret_id, version = "latest" }
  }

  depends_on = [module.cloud_sql, module.secrets_stage, google_sql_user.stage]
}

# ── Worker + Scheduler de stage (Cloud Run Jobs) ─────────────────────────────
locals {
  stage_job_env_vars = {
    APP_ENV              = "production"
    APP_DEBUG            = "false"
    APP_URL              = "https://${local.stage_webapp_host}"
    LOG_CHANNEL          = "stderr"
    DB_CONNECTION        = "pgsql"
    DB_SOCKET            = local.cloudsql_socket
    DB_DATABASE          = "turni_stage"
    DB_USERNAME          = "turni_stage"
    QUEUE_CONNECTION     = "database"
    MAIL_MAILER          = "resend"
    MAIL_FROM_ADDRESS    = local.stage_mail_from_address
    MAIL_FROM_NAME       = "Turni"
    LOG_STDERR_FORMATTER = "Monolog\\Formatter\\JsonFormatter"
    PAGARME_DRIVER       = "mock"
    PAGARME_BASE_URL     = google_cloud_run_v2_service.pagarme_mock_stage.uri
  }

  stage_job_secret_env_vars = {
    APP_KEY                = { secret = module.secrets_stage.app_key_api_secret_id, version = "latest" }
    DB_PASSWORD            = { secret = module.secrets_stage.db_password_secret_id, version = "latest" }
    RESEND_API_KEY         = { secret = module.secrets_stage.resend_api_key_secret_id, version = "latest" }
    PAGARME_SECRET_KEY     = { secret = google_secret_manager_secret.pagarme_secret_key_stage.secret_id, version = "latest" }
    PAGARME_WEBHOOK_SECRET = { secret = google_secret_manager_secret.pagarme_webhook_secret_stage.secret_id, version = "latest" }
    PIX_FALHA_CHAVE_KEY    = { secret = google_secret_manager_secret.pix_falha_chave_key_stage.secret_id, version = "latest" }
  }
}

module "worker_job_stage" {
  source                   = "../../modules/worker-job"
  project_id               = var.project_id
  region                   = var.region
  env                      = local.stage_env
  image                    = var.api_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  vpc_network              = google_compute_network.main.name
  vpc_subnetwork           = google_compute_subnetwork.stage.name

  env_vars        = local.stage_job_env_vars
  secret_env_vars = local.stage_job_secret_env_vars

  depends_on = [module.cloud_sql, module.secrets_stage, google_sql_user.stage]
}

module "scheduler_job_stage" {
  source                   = "../../modules/worker-job"
  project_id               = var.project_id
  region                   = var.region
  env                      = local.stage_env
  name                     = "scheduler"
  sa_account_short         = "schd"
  command                  = ["php", "artisan", "schedule:run"]
  image                    = var.api_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  vpc_network              = google_compute_network.main.name
  vpc_subnetwork           = google_compute_subnetwork.stage.name

  env_vars        = local.stage_job_env_vars
  secret_env_vars = local.stage_job_secret_env_vars

  depends_on = [module.cloud_sql, module.secrets_stage, google_sql_user.stage]
}

# ── Fake de pagamento de stage (PDR-017 / ADR-016 d) ─────────────────────────
resource "google_secret_manager_secret" "pagarme_secret_key_stage" {
  project   = var.project_id
  secret_id = "turni-${local.stage_env}-pagarme-secret-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "pagarme_secret_key_stage" {
  secret      = google_secret_manager_secret.pagarme_secret_key_stage.id
  secret_data = var.pagarme_secret_key_stage
}

resource "google_secret_manager_secret" "pagarme_webhook_secret_stage" {
  project   = var.project_id
  secret_id = "turni-${local.stage_env}-pagarme-webhook-secret"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "pagarme_webhook_secret_stage" {
  secret      = google_secret_manager_secret.pagarme_webhook_secret_stage.id
  secret_data = var.pagarme_webhook_secret_stage
}

resource "google_secret_manager_secret" "pix_falha_chave_key_stage" {
  project   = var.project_id
  secret_id = "turni-${local.stage_env}-pix-falha-chave-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "pix_falha_chave_key_stage" {
  secret      = google_secret_manager_secret.pix_falha_chave_key_stage.id
  secret_data = var.pix_falha_chave_key_stage
}

resource "google_cloud_run_v2_service" "pagarme_mock_stage" {
  project             = var.project_id
  name                = "turni-pagarme-mock-${local.stage_env}"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = module.iam.apps_service_account_email

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      image = var.pagarme_mock_image

      ports {
        container_port = 8080
      }

      env {
        name  = "PAGARME_WEBHOOK_TARGET"
        value = var.api_public_url_stage != "" ? "${var.api_public_url_stage}/api/webhooks/pagarme" : "https://api-pending.invalid/api/webhooks/pagarme"
      }
      env {
        name  = "PAGARME_MOCK_PIX_RESULTADO"
        value = var.pagarme_mock_pix_resultado
      }
      env {
        name  = "PAGARME_MOCK_PIX_SLA_SEGUNDOS"
        value = tostring(var.pagarme_mock_pix_sla_segundos)
      }
      env {
        name  = "PHP_CLI_SERVER_WORKERS"
        value = "8"
      }
      env {
        name = "PAGARME_SECRET_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.pagarme_secret_key_stage.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "PAGARME_WEBHOOK_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.pagarme_webhook_secret_stage.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = false
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 10
        period_seconds        = 30
        timeout_seconds       = 5
        failure_threshold     = 3
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }

  depends_on = [
    google_secret_manager_secret_version.pagarme_secret_key_stage,
    google_secret_manager_secret_version.pagarme_webhook_secret_stage,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "pagarme_mock_stage_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.pagarme_mock_stage.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ── Firebase Hosting de stage (WebApp + landing) — site_id NOVOS ─────────────
# turni-webapp-stage / turni-landing-stage ficam reservados globalmente pelo
# turni-stage até o delete propagar; usamos ids novos no turni-homol.
module "firebase_stage" {
  source         = "../../modules/firebase"
  project_id     = var.project_id
  env            = local.stage_env
  webapp_site_id = "turni-homol-stage-webapp"
  custom_domain  = local.stage_webapp_host
  additional_sites = {
    landing = {
      site_id       = "turni-homol-stage-landing"
      custom_domain = local.stage_landing_host
    }
  }
  depends_on = [google_project_service.apis]
}

# ── DNS de stage (zona stage.turni.com.br agora no turni-homol) ──────────────
module "dns_stage" {
  source               = "../../modules/dns"
  project_id           = var.project_id
  create_zone          = true
  dns_zone_name        = "stage-turni-com-br"
  zone_dns_name        = "stage.turni.com.br."
  webapp_subdomain     = local.stage_webapp_host
  webapp_cname_target  = module.firebase_stage.cname_target
  landing_subdomain    = local.stage_landing_host
  landing_cname_target = module.firebase_stage.additional_cname_targets["landing"]

  mail_sender_domain = local.stage_mail_sender_domain
  mail_dkim_value    = var.mail_dkim_value_stage

  depends_on = [google_project_service.apis, module.firebase_stage]
}

# ── Monitoramento de stage ───────────────────────────────────────────────────
module "monitoring_stage" {
  source      = "../../modules/monitoring"
  project_id  = var.project_id
  env         = local.stage_env
  alert_email = var.alert_email
  api_host    = local.stage_api_host
  admin_host  = local.stage_admin_host
  webapp_host = local.stage_webapp_host
  depends_on  = [google_project_service.apis]
}
