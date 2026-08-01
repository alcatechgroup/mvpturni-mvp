output "instance_name" {
  description = "Nome da instância (usado pelo deploy via `gcloud compute ssh`)"
  value       = google_compute_instance.this.name
}

output "instance_self_link" {
  description = "Self link da instância"
  value       = google_compute_instance.this.self_link
}

output "zone" {
  description = "Zona da instância"
  value       = google_compute_instance.this.zone
}

output "external_ip" {
  description = "IP público estático da VPS (alvo dos registros A na Cloudflare)"
  value       = google_compute_address.this.address
}

output "service_account_email" {
  description = "E-mail da service account da VPS"
  value       = google_service_account.vm.email
}

output "config_bucket" {
  description = "Bucket com o runtime publicado (compose, Caddyfile, scripts)"
  value       = google_storage_bucket.config.name
}

output "backups_bucket" {
  description = "Bucket de destino dos dumps do Postgres"
  value       = google_storage_bucket.backups.name
}

output "data_disk_name" {
  description = "Nome do disco de dados"
  value       = google_compute_disk.data.name
}
