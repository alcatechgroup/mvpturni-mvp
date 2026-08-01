output "ci_service_account_email" {
  description = "E-mail da SA do CI — secret GCP_SERVICE_ACCOUNT no GitHub"
  value       = google_service_account.ci.email
}

output "workload_identity_provider" {
  description = "Resource name do provider WIF — secret GCP_WORKLOAD_IDENTITY_PROVIDER no GitHub"
  value       = google_iam_workload_identity_pool_provider.github.name
}
