# Outputs do ambiente STAGE co-localizado (ver stage.tf).

output "api_url_stage" {
  value = module.cloud_run_api_stage.service_url
}

output "admin_url_stage" {
  value = module.cloud_run_admin_stage.service_url
}

output "firebase_site_id_stage" {
  value = module.firebase_stage.site_id
}

output "landing_site_id_stage" {
  value = module.firebase_stage.additional_site_ids["landing"]
}

output "dns_name_servers_stage" {
  description = "Nameservers da zona stage.turni.com.br (no turni-homol) — re-delegar no apex turni.com.br (turni-prod)"
  value       = module.dns_stage.name_servers
}
