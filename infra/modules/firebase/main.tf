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
