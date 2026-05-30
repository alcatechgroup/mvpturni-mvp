# Agendamento de liga/desliga do Cloud SQL para redução de custo em homolog.
# Desliga: segunda a sexta às 22h BRT; finais de semana ficam off.
# Liga: SQL às 06h BRT.
# Usa Cloud Scheduler → REST API diretamente (sem Cloud Functions).
#
# NOTA (IDR-016): o ramo de liga/desliga do GCE worker saiu deste módulo. O worker
# agora é um Cloud Run Job acionado pelo Scheduler a cada 1 min (`--stop-when-empty`),
# sem instância sempre-ligada a gerenciar — ver modules/worker-job.

locals {
  sql_url = "https://sqladmin.googleapis.com/v1/projects/${var.project_id}/instances/${var.instance_name}"
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

# ── STOP: SQL às 22:00 BRT ───────────────────────────────────────────────────
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

# ── START: SQL às 06:00 BRT ──────────────────────────────────────────────────
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
