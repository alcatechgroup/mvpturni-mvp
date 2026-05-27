output "ci_service_account_email" {
  description = "E-mail da service account do CI (GitHub Actions)"
  value       = google_service_account.ci.email
}

output "apps_service_account_email" {
  description = "E-mail da service account das apps em runtime"
  value       = google_service_account.apps.email
}

output "workload_identity_provider" {
  description = "Resource name completo do WIF Provider (para o GitHub Actions secret)"
  value       = google_iam_workload_identity_pool_provider.github.name
}
