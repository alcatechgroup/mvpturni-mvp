output "secret_ids" {
  description = "Mapa papel => secret_id criado (ex.: app-key-api => turni-homolog-app-key-api)"
  value       = { for k, s in google_secret_manager_secret.this : k => s.secret_id }
}

output "secret_id_list" {
  description = "Lista dos secret_id (para conceder acesso em bloco à SA da VPS)"
  value       = [for s in google_secret_manager_secret.this : s.secret_id]
}
