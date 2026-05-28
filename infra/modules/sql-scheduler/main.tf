# Agendamento de liga/desliga do Cloud SQL para redução de custo em homolog.
# Desliga: segunda a sexta às 22h BRT; não liga em sábado e domingo.
# Liga: segunda a sexta às 06h BRT.
# Usa Cloud Scheduler → SQL Admin REST API (sem Cloud Functions).

locals {
  instance_url = "https://sqladmin.googleapis.com/v1/projects/${var.project_id}/instances/${var.instance_name}"
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

# ── Desliga: seg–sex às 22:00 BRT (finais de semana ficam desligados) ─────────
resource "google_cloud_scheduler_job" "sql_stop" {
  project     = var.project_id
  region      = var.region
  name        = "turni-${var.env}-sql-stop"
  description = "Para Cloud SQL ${var.env} às 22h BRT (seg–sex + weekend off)"
  schedule    = "0 22 * * 1-5"
  time_zone   = "America/Sao_Paulo"

  http_target {
    uri         = local.instance_url
    http_method = "PATCH"
    body        = base64encode(jsonencode({ settings = { activationPolicy = "NEVER" } }))

    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = google_service_account.sql_scheduler.email
      scope                 = "https://www.googleapis.com/auth/sqlservice.admin"
    }
  }
}

# ── Liga: seg–sex às 06:00 BRT ────────────────────────────────────────────────
resource "google_cloud_scheduler_job" "sql_start" {
  project     = var.project_id
  region      = var.region
  name        = "turni-${var.env}-sql-start"
  description = "Inicia Cloud SQL ${var.env} às 06h BRT (seg–sex)"
  schedule    = "0 6 * * 1-5"
  time_zone   = "America/Sao_Paulo"

  http_target {
    uri         = local.instance_url
    http_method = "PATCH"
    body        = base64encode(jsonencode({ settings = { activationPolicy = "ALWAYS" } }))

    headers = {
      "Content-Type" = "application/json"
    }

    oauth_token {
      service_account_email = google_service_account.sql_scheduler.email
      scope                 = "https://www.googleapis.com/auth/sqlservice.admin"
    }
  }
}
