# Artifact Registry — repositório Docker para imagens de api e admin.
resource "google_artifact_registry_repository" "turni" {
  project       = var.project_id
  location      = var.region
  repository_id = "turni"
  format        = "DOCKER"
  description   = "Imagens Docker do Turni (api, admin)"
}
