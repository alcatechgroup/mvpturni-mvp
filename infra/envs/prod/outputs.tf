output "external_ip" {
  description = "IP público da VPS de prod"
  value       = module.prod.external_ip
}

output "instance_name" {
  description = "Nome da instância (alvo do deploy via IAP)"
  value       = module.prod.instance_name
}

output "zone" {
  description = "Zona da instância"
  value       = module.prod.zone
}

output "urls" {
  description = "URLs públicas do ambiente"
  value       = module.prod.urls
}

output "config_bucket" {
  description = "Bucket com o runtime publicado na VPS"
  value       = module.prod.config_bucket
}

output "backups_bucket" {
  description = "Bucket dos dumps do Postgres"
  value       = module.prod.backups_bucket
}

output "ssh_command" {
  description = "Comando pronto para abrir shell na VPS (sem porta 22 exposta)"
  value       = "gcloud compute ssh ${module.prod.instance_name} --zone ${module.prod.zone} --project ${var.project_id} --tunnel-through-iap"
}
