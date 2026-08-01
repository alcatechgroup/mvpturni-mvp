output "external_ip" {
  description = "IP público da VPS de staging"
  value       = module.staging.external_ip
}

output "instance_name" {
  description = "Nome da instância (alvo do deploy via IAP)"
  value       = module.staging.instance_name
}

output "zone" {
  description = "Zona da instância"
  value       = module.staging.zone
}

output "urls" {
  description = "URLs públicas do ambiente"
  value       = module.staging.urls
}

output "config_bucket" {
  description = "Bucket com o runtime publicado na VPS"
  value       = module.staging.config_bucket
}

output "backups_bucket" {
  description = "Bucket dos dumps do Postgres"
  value       = module.staging.backups_bucket
}

output "ssh_command" {
  description = "Comando pronto para abrir shell na VPS (sem porta 22 exposta)"
  value       = "gcloud compute ssh ${module.staging.instance_name} --zone ${module.staging.zone} --project ${var.project_id} --tunnel-through-iap"
}
