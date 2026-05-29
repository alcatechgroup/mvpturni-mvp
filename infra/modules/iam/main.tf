# Workload Identity Federation + service accounts para CI/CD e apps.
# Permite que o GitHub Actions se autentique no GCP sem chave de longa duração.

resource "google_service_account" "ci" {
  project      = var.project_id
  account_id   = "turni-github-ci"
  display_name = "Turni GitHub Actions CI/CD"
}

resource "google_service_account" "apps" {
  project      = var.project_id
  account_id   = "turni-apps"
  display_name = "Turni Apps Runtime (Cloud Run + Worker)"
}

# Workload Identity Pool — representa o GitHub OIDC como provedor de identidade
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  # Restringe ao repositório correto (evita que qualquer repo GitHub use o pool)
  attribute_condition = "attribute.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Permite que o CI assuma a service account via WIF
resource "google_service_account_iam_binding" "ci_wif" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}",
  ]
}

# Permissões do CI: Artifact Registry writer, Cloud Run developer, Firebase Admin
resource "google_project_iam_member" "ci_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_firebase_hosting" {
  project = var.project_id
  role    = "roles/firebasehosting.admin"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

resource "google_project_iam_member" "ci_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

# Cloud SQL admin: o job de migração do pipeline (release.yml migrate-homolog)
# precisa ligar a instância (scheduler de economia pode tê-la desligado) e
# executar migrações. STORY-016.
resource "google_project_iam_member" "ci_cloudsql_admin" {
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.ci.email}"
}

# Permissões do runtime das apps: Cloud SQL client, Secret Manager accessor, Logging writer
resource "google_project_iam_member" "apps_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.apps.email}"
}

resource "google_project_iam_member" "apps_secretmanager" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.apps.email}"
}

resource "google_project_iam_member" "apps_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.apps.email}"
}
