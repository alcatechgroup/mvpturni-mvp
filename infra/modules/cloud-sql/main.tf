# Cloud SQL PostgreSQL gerenciado (ADR-000, ADR-004).
# Uma única instância compartilhada entre api, admin e worker — dados + fila database.

resource "google_sql_database_instance" "main" {
  project             = var.project_id
  name                = "turni-${var.env}"
  region              = var.region
  database_version    = "POSTGRES_17"
  deletion_protection = var.env == "prod"

  settings {
    tier              = var.db_tier
    edition           = "ENTERPRISE"
    availability_type = var.env == "prod" ? "REGIONAL" : "ZONAL"
    disk_autoresize   = true
    disk_size         = 10

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled    = false # sem IP público; acesso via Cloud SQL connector
      private_network = var.vpc_network
      # Hardening: permite serviços Google alcançarem a instância pelo path privado.
      # (O que destrava Cloud Run → Cloud SQL de IP privado é o Direct VPC egress nas
      # services/jobs — ver módulo cloud-run e release.yml. STORY-016.)
      enable_private_path_for_google_cloud_services = true
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }
}

resource "google_sql_database" "turni" {
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  name     = "turni"
}

resource "google_sql_user" "app" {
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  name     = "turni"
  password = var.db_password
}
