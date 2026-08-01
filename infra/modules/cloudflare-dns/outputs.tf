output "fqdns" {
  description = "FQDN efetivo de cada papel (papel => nome completo publicado na zona)"
  value       = { for k, r in cloudflare_dns_record.app : k => r.name }
}
