# Agendamento de liga/desliga do Cloud SQL + GCE worker para redução de custo em homolog.
# Desliga: segunda a sexta às 22h BRT (worker e SQL juntos); finais de semana ficam off.
# Liga: SQL às 06h BRT, worker às 06h05 BRT (5 min de buffer para o DB subir).
# Usa Cloud Scheduler → REST API diretamente (sem Cloud Functions).

locals {
  sql_url    = "https://sqladmin.googleapis.com/v1/projects/${var.project_id}/instances/${var.instance_name}"
  worker_url = "https://compute.googleapis.com/compute/v1/projects/${var.project_id}/zones/${var.worker_zone}/instances/${var.worker_instance_name}"
}

# ── Service account dedicada (princípio do menor privilégio) ──────────────────
resource "google_service_account" "sql_scheduler" {
  project      = var.project_id
  account_id   = "turni-sql-sched-${var.env}"
  display_name = "Turni SQL Scheduler (${var.env})"
}

resource "google_project_iam_member" "sql_scheduler_admin" {
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.sql_scheduler.email}"
}

# Permissão de start/stop na instância GCE específica (sem instanceAdmin no projeto inteiro)
resource "google_compute_instance_iam_member" "scheduler_worker" {
  project  = var.project_id
  zone     = var.worker_zone
  instance = var.worker_instance_name
  role     = "roles/compute.instanceAdmin.v1"
  member   = "serviceAccount:${google_service_account.sql_scheduler.email}"
}

# ── STOP: SQL às 22:00 BRT, worker junto ─────────────────────────────────────
resource "google_cloud_scheduler_job" "sql_stop" {
  project     = var.project_id
  region      = var.region
  name        = "turni-${var.env}-sql-stop"
  description = "Para Cloud SQL ${var.env} às 22h BRT (seg–sex + weekend off)"
  schedule    = "0 22 * * 1-5"
  time_zone   = "America/Sao_Paulo"

  http_target {
    uri         = local.sql_url
    http_method = "PATCH"
    body        = base64encode(jsonencode({ settings = { activationPolicy = "NEVER" } }))
    headers     = { "Content-Type" = "application/json" }

    oauth_token {
      service_account_email = google_service_account.sql_scheduler.email
      scope                 = "https://www.googleapis.com/auth/sqlservice.admin"
    }
  }
}

resource "google_cloud_scheduler_job" "worker_stop" {
  project     = var.project_id
  region      = var.region
  name        = "turni-${var.env}-worker-stop"
  description = "Para GCE worker ${var.env} às 22h BRT (seg–sex + weekend off)"
  schedule    = "0 22 * * 1-5"
  time_zone   = "America/Sao_Paulo"

  http_target {
    uri         = "${local.worker_url}/stop"
    http_method = "POST"
    body        = base64encode("{}")
    headers     = { "Content-Type" = "application/json" }

    oauth_token {
      service_account_email = google_service_account.sql_scheduler.email
      scope                 = "https://www.googleapis.com/auth/compute"
    }
  }
}

# ── START: SQL às 06:00 BRT, worker às 06:05 (aguarda DB subir) ───────────────
resource "google_cloud_scheduler_job" "sql_start" {
  project     = var.project_id
  region      = var.region
  name        = "turni-${var.env}-sql-start"
  description = "Inicia Cloud SQL ${var.env} às 06h BRT (seg–sex)"
  schedule    = "0 6 * * 1-5"
  time_zone   = "America/Sao_Paulo"

  http_target {
    uri         = local.sql_url
    http_method = "PATCH"
    body        = base64encode(jsonencode({ settings = { activationPolicy = "ALWAYS" } }))
    headers     = { "Content-Type" = "application/json" }

    oauth_token {
      service_account_email = google_service_account.sql_scheduler.email
      scope                 = "https://www.googleapis.com/auth/sqlservice.admin"
    }
  }
}

resource "google_cloud_scheduler_job" "worker_start" {
  project     = var.project_id
  region      = var.region
  name        = "turni-${var.env}-worker-start"
  description = "Inicia GCE worker ${var.env} às 06h05 BRT — 5 min após o SQL (seg–sex)"
  schedule    = "5 6 * * 1-5"
  time_zone   = "America/Sao_Paulo"

  http_target {
    uri         = "${local.worker_url}/start"
    http_method = "POST"
    body        = base64encode("{}")
    headers     = { "Content-Type" = "application/json" }

    oauth_token {
      service_account_email = google_service_account.sql_scheduler.email
      scope                 = "https://www.googleapis.com/auth/compute"
    }
  }
}
