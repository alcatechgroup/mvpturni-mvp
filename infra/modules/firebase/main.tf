# Firebase Hosting para o WebApp Flutter (bundle estático + PWA).
# Requer provider google-beta.

resource "google_firebase_hosting_site" "webapp" {
  provider = google-beta
  project  = var.project_id
  site_id  = "turni-webapp-${var.env}"
}

# Configuração do site (headers de cache, rewrite para Flutter SPA)
resource "google_firebase_hosting_release" "default" {
  provider = google-beta
  count    = 0  # gerenciado pelo CI via firebase deploy — não pelo Terraform
  site_id  = google_firebase_hosting_site.webapp.site_id

  lifecycle {
    ignore_changes = all
  }
}
