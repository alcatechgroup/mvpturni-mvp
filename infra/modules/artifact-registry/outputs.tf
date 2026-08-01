output "repository_url" {
  description = "URL base do repositório (prefixo das imagens)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.turni.repository_id}"
}

output "repository_id" {
  description = "Nome do repositório"
  value       = google_artifact_registry_repository.turni.repository_id
}
