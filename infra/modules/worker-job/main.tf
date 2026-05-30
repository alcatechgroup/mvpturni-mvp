# Worker da fila como Cloud Run Job + Cloud Scheduler (IDR-016, substitui worker-vm).
# Cloud Scheduler dispara o Job a cada 1 min; o Job roda `queue:work --stop-when-empty`
# e termina quando a fila esvazia. Herda a fiação do cloud-run (Direct VPC egress +
# volumes.cloud_sql_instance + secret_env_vars) provada pelo turni-migrate-homolog (IDR-007).

# ── Cloud Run Job ──────────────────────────────────────────────────────────────
resource "google_cloud_run_v2_job" "worker" {
  project  = var.project_id
  name     = "turni-worker-job-${var.env}"
  location = var.region

  # Homolog é recriável do zero (CA-11: terraform destroy + apply). Sem isto o
  # provider default (true) bloquearia o destroy do Job.
  deletion_protection = false

  template {
    template {
      service_account = var.service_account_email
      max_retries     = var.max_retries
      timeout         = var.task_timeout

      # Cloud SQL connector via socket (sem proxy externo) — mesmo padrão do cloud-run.
      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [var.cloudsql_connection_name]
        }
      }

      # Direct VPC egress — alcança o Cloud SQL de IP privado (IDR-007). PRIVATE_RANGES_ONLY
      # usa o Google front-end para tráfego público (Resend), dispensando Cloud NAT.
      vpc_access {
        network_interfaces {
          network    = var.vpc_network
          subnetwork = var.vpc_subnetwork
        }
        egress = "PRIVATE_RANGES_ONLY"
      }

      containers {
        image   = var.image
        command = var.command

        dynamic "env" {
          for_each = var.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = var.secret_env_vars
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value.secret
                version = env.value.version
              }
            }
          }
        }

        volume_mounts {
          name       = "cloudsql"
          mount_path = "/cloudsql"
        }

        resources {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      # O pipeline (release.yml) gerencia a imagem; o Terraform não sobrescreve.
      template[0].template[0].containers[0].image,
    ]
  }
}

# ── SA dedicada do Scheduler (menor privilégio: só roles/run.invoker no Job) ──────
resource "google_service_account" "worker_scheduler" {
  project      = var.project_id
  account_id   = "turni-wrk-sched-${var.env}"
  display_name = "Turni Worker Job Scheduler (${var.env})"
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.worker.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.worker_scheduler.email}"
}

# ── Cloud Scheduler: dispara o Job a cada 1 min ──────────────────────────────────
# Chama a Admin API do Cloud Run (run.googleapis.com) — API do Google, portanto
# oauth_token (escopo cloud-platform), não oidc_token. A autorização vem do
# roles/run.invoker (que inclui run.jobs.run) acima. Ver IDR-016 §OAuth vs OIDC.
resource "google_cloud_scheduler_job" "worker_tick" {
  project     = var.project_id
  region      = var.region
  name        = "turni-worker-scheduler-${var.env}"
  description = "Dispara o worker job ${var.env} a cada 1 min (queue:work --stop-when-empty)"
  schedule    = var.schedule
  time_zone   = var.time_zone

  attempt_deadline = "320s"

  http_target {
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.worker.name}:run"
    http_method = "POST"

    oauth_token {
      service_account_email = google_service_account.worker_scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  depends_on = [google_cloud_run_v2_job_iam_member.scheduler_invoker]
}
