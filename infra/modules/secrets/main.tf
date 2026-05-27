# Secret Manager — segredos das apps (nunca em git, ADR-004).
# Os valores são provisionados fora do Terraform (bootstrap manual ou SOPS);
# o Terraform cria o shell do segredo e as permissões de acesso.

resource "google_secret_manager_secret" "app_key_api" {
  project   = var.project_id
  secret_id = "turni-${var.env}-app-key-api"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "app_key_admin" {
  project   = var.project_id
  secret_id = "turni-${var.env}-app-key-admin"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = "turni-${var.env}-db-password"
  replication {
    auto {}
  }
}

# Versão inicial dos segredos (valor placeholder; substituir manualmente antes do deploy)
resource "google_secret_manager_secret_version" "app_key_api" {
  secret      = google_secret_manager_secret.app_key_api.id
  secret_data = var.app_key_api
}

resource "google_secret_manager_secret_version" "app_key_admin" {
  secret      = google_secret_manager_secret.app_key_admin.id
  secret_data = var.app_key_admin
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}
