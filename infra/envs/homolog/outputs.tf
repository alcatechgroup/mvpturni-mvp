output "wif_provider" {
  description = "Valor para o GitHub secret GCP_WORKLOAD_IDENTITY_PROVIDER"
  value       = module.iam.workload_identity_provider
}

output "ci_service_account" {
  description = "Valor para o GitHub secret GCP_SERVICE_ACCOUNT"
  value       = module.iam.ci_service_account_email
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "api_url" {
  value = module.cloud_run_api.service_url
}

output "admin_url" {
  value = module.cloud_run_admin.service_url
}

output "firebase_site_id" {
  value = module.firebase.site_id
}
