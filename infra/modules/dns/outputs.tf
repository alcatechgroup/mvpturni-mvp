output "name_servers" {
  description = "Name servers da zona (configurar no registrador do domínio)"
  value       = var.create_zone ? google_dns_managed_zone.turni[0].name_servers : []
}
