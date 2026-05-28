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

output "landing_site_id" {
  description = "site_id do site Firebase da landing homolog"
  value       = module.firebase.additional_site_ids["landing"]
}

output "landing_default_url" {
  description = "URL default do site da landing homolog (placeholder até STORY-030 importar conteúdo)"
  value       = "https://${module.firebase.additional_site_ids["landing"]}.web.app"
}

output "dns_name_servers" {
  description = "Nameservers para configurar no registro.br (delegar turni.com.br para o Cloud DNS)"
  value       = module.dns.name_servers
}
