output "repository_url" {
  description = "URL base do repositório (usar como prefixo das imagens)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.turni.repository_id}"
}
