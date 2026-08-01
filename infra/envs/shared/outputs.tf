output "registry_url" {
  description = "URL base do Artifact Registry — entrada `registry_url` dos ambientes"
  value       = module.artifact_registry.repository_url
}

output "ci_service_account_email" {
  description = "SA do CI — secret GCP_SERVICE_ACCOUNT no GitHub e `deployer_members` dos ambientes"
  value       = module.iam.ci_service_account_email
}

output "ci_service_account_member" {
  description = "Membro IAM da SA do CI, no formato aceito por `deployer_members`"
  value       = "serviceAccount:${module.iam.ci_service_account_email}"
}

output "workload_identity_provider" {
  description = "Provider WIF — secret GCP_WORKLOAD_IDENTITY_PROVIDER no GitHub"
  value       = module.iam.workload_identity_provider
}
