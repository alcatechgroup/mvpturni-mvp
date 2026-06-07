output "wif_provider" {
  description = "Valor para o GitHub secret GCP_WORKLOAD_IDENTITY_PROVIDER (Environment prod)"
  value       = module.iam.workload_identity_provider
}

output "ci_service_account" {
  description = "Valor para o GitHub secret GCP_SERVICE_ACCOUNT (Environment prod)"
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
  description = "site_id do WebApp prod (null enquanto parado — firebase só sobe no go-live)"
  value       = one(module.firebase[*].site_id)
}

# RAIZ do domínio: delegar turni.com.br para estes nameservers NO REGISTRO.BR (cutover
# único do modelo de 3 projetos). Depois, as zonas filhas (homolog./stage.) são alcançadas
# via os registros NS de delegação que esta zona publica (var.delegations).
output "dns_name_servers" {
  description = "Nameservers da zona apex turni.com.br — configurar no registro.br"
  value       = module.dns.name_servers
}
