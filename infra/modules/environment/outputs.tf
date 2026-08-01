output "instance_name" {
  description = "Nome da VPS (alvo do `gcloud compute ssh` do deploy)"
  value       = module.vps.instance_name
}

output "zone" {
  description = "Zona da VPS"
  value       = module.vps.zone
}

output "external_ip" {
  description = "IP público da VPS"
  value       = module.vps.external_ip
}

output "vps_service_account" {
  description = "SA da VPS"
  value       = module.vps.service_account_email
}

output "config_bucket" {
  description = "Bucket com o runtime publicado"
  value       = module.vps.config_bucket
}

output "backups_bucket" {
  description = "Bucket dos dumps do Postgres"
  value       = module.vps.backups_bucket
}

output "hosts" {
  description = "FQDNs publicados do ambiente"
  value       = local.hosts
}

output "urls" {
  description = "URLs de acesso do ambiente"
  value = {
    webapp  = "https://${local.hosts.webapp}"
    admin   = "https://${local.hosts.admin}"
    api     = "https://${local.hosts.api}"
    landing = "https://${local.hosts.landing}"
  }
}

output "secret_ids" {
  description = "Mapa papel => secret_id do ambiente"
  value       = module.secrets.secret_ids
}
