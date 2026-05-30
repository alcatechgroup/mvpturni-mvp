# Módulo Cloud Run genérico — usado para api e admin.
# Parâmetros de ingress e IAP distinguem api (público) de admin (interno + IAP).

resource "google_cloud_run_v2_service" "service" {
  project  = var.project_id
  name     = "turni-${var.app}-${var.env}"
  location = var.region

  ingress = var.ingress # INGRESS_TRAFFIC_ALL (api) | INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER (admin)

  template {
    service_account = var.service_account_email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # Cloud SQL connector via socket (sem proxy externo)
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [var.cloudsql_connection_name]
      }
    }

    # Direct VPC egress — alcança o Cloud SQL de IP privado (STORY-016). Sem isto o
    # connector cloudsql-instances dá timeout no socket. Só quando subnet é informada.
    dynamic "vpc_access" {
      for_each = var.vpc_subnetwork != null ? [1] : []
      content {
        network_interfaces {
          network    = var.vpc_network
          subnetwork = var.vpc_subnetwork
        }
        egress = "PRIVATE_RANGES_ONLY"
      }
    }

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      # Variáveis de ambiente não-secretas
      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Variáveis vindas do Secret Manager
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
    ignore_changes = [
      # O pipeline gerencia a imagem; o Terraform não sobrescreve deploys do CI
      template[0].containers[0].image,
    ]
  }
}

# Acesso público para api; admin usa IAP (configurado no LB externo)
resource "google_cloud_run_v2_service_iam_member" "public" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
