output "external_ip" {
  description = "IP público da VPS de homologação"
  value       = module.homolog.external_ip
}

output "instance_name" {
  description = "Nome da instância (alvo do deploy via IAP)"
  value       = module.homolog.instance_name
}

output "zone" {
  description = "Zona da instância"
  value       = module.homolog.zone
}

output "urls" {
  description = "URLs públicas do ambiente"
  value       = module.homolog.urls
}

output "config_bucket" {
  description = "Bucket com o runtime publicado na VPS"
  value       = module.homolog.config_bucket
}

output "backups_bucket" {
  description = "Bucket dos dumps do Postgres"
  value       = module.homolog.backups_bucket
}

output "ssh_command" {
  description = "Comando pronto para abrir shell na VPS (sem porta 22 exposta)"
  value       = "gcloud compute ssh ${module.homolog.instance_name} --zone ${module.homolog.zone} --project ${var.project_id} --tunnel-through-iap"
}
