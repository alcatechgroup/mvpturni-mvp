output "network_name" {
  description = "Nome da VPC do ambiente"
  value       = google_compute_network.this.name
}

output "network_self_link" {
  description = "Self link da VPC (para anexar instâncias)"
  value       = google_compute_network.this.self_link
}

output "subnetwork_self_link" {
  description = "Self link da subnet regional"
  value       = google_compute_subnetwork.this.self_link
}

output "tag_web" {
  description = "Network tag que libera 80/443 vindo da Cloudflare"
  value       = local.tag_web
}

output "tag_ssh" {
  description = "Network tag que libera 22 vindo do IAP"
  value       = local.tag_ssh
}
