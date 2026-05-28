# Firebase Hosting para o WebApp Flutter (bundle estático + PWA).
# Requer provider google-beta.

resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id
}

resource "google_firebase_hosting_site" "webapp" {
  provider   = google-beta
  project    = var.project_id
  site_id    = "turni-webapp-${var.env}"
  depends_on = [google_firebase_project.default]
}

# Domínio customizado (ex: app.homolog.turni.com.br).
# Firebase verifica a posse via CNAME que já deve estar no Cloud DNS antes deste apply.
# O CNAME esperado: app.homolog.turni.com.br → turni-webapp-<env>.web.app
resource "google_firebase_hosting_custom_domain" "webapp" {
  count         = var.custom_domain != null ? 1 : 0
  provider      = google-beta
  project       = var.project_id
  site_id       = google_firebase_hosting_site.webapp.site_id
  custom_domain = var.custom_domain
  depends_on    = [google_firebase_hosting_site.webapp]
}
