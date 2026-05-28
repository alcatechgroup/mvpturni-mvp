output "site_id" {
  description = "site_id do site principal (WebApp)"
  value       = google_firebase_hosting_site.webapp.site_id
}

output "default_url" {
  value = "https://${google_firebase_hosting_site.webapp.site_id}.web.app"
}

output "cname_target" {
  description = "Valor do CNAME a adicionar no DNS para o domínio customizado do WebApp"
  value       = "${google_firebase_hosting_site.webapp.site_id}.web.app"
}

output "additional_site_ids" {
  description = "Mapa chave → site_id dos sites adicionais (ex: landing → turni-landing-homolog)"
  value       = { for k, s in google_firebase_hosting_site.additional : k => s.site_id }
}

output "additional_cname_targets" {
  description = "Mapa chave → target CNAME (<site_id>.web.app) dos sites adicionais"
  value       = { for k, s in google_firebase_hosting_site.additional : k => "${s.site_id}.web.app" }
}
