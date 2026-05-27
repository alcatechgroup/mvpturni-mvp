output "site_id" {
  value = google_firebase_hosting_site.webapp.site_id
}

output "default_url" {
  value = "https://${google_firebase_hosting_site.webapp.site_id}.web.app"
}
