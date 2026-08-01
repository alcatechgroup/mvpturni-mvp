# Identidade do CI/CD do Turni no projeto FoodHub (recurso COMPARTILHADO entre os
# três ambientes — vive em infra/envs/shared).
#
# Workload Identity Federation: o GitHub Actions troca o token OIDC do workflow por
# credencial GCP de curta duração. Nenhuma chave de service account existe, logo
# nenhuma pode vazar (ADR-004 §f, mantido pela ADR-021).
#
# O que o CI passou a precisar com a VPS (mudou em relação ao Cloud Run):
#   • artifactregistry.writer — empurrar as imagens de release;
#   • compute.viewer          — descrever a instância alvo do deploy;
#   • compute.osAdminLogin    — SSH via OS Login com sudo (o deploy.sh usa sudo);
#   • iap.tunnelResourceAccessor — abrir o túnel IAP (não há porta 22 na internet).
# O `iam.serviceAccountUser` sobre a SA da VPS é concedido no módulo vps, por
# ambiente, para que o CI não ganhe poder sobre SAs de outras apps da FoodHub.

resource "google_service_account" "ci" {
  project      = var.project_id
  account_id   = var.ci_account_id
  display_name = "Turni — GitHub Actions CI/CD"
  description  = "Identidade federada do pipeline do Turni (build + deploy nas VPS)"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "Turni GitHub Actions"
  description               = "Pool OIDC do repositório ${var.github_repo}"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Sem esta condição, qualquer repositório do GitHub poderia trocar seu token por
  # credencial deste projeto.
  attribute_condition = "attribute.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "ci_wif" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

resource "google_project_iam_member" "ci" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/compute.viewer",
    "roles/compute.osAdminLogin",
    "roles/iap.tunnelResourceAccessor",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ci.email}"
}
