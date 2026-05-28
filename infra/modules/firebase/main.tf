# Firebase Hosting — múltiplos sites estáticos no mesmo projeto GCP.
# Site principal: WebApp Flutter (bundle estático + PWA).
# Sites adicionais (EPIC-006): landing institucional, micro-site de redirect www.
# Requer provider google-beta.
#
# Decisão de topologia: um único google_firebase_project (singleton por projeto) +
# N sites de hosting via var.additional_sites. Ver IDR-005 (Opção A vs. B).

resource "google_firebase_project" "default" {
  provider = google-beta
  project  = var.project_id
}

# ── Site principal (WebApp) ───────────────────────────────────────────────────
resource "google_firebase_hosting_site" "webapp" {
  provider   = google-beta
  project    = var.project_id
  site_id    = "turni-webapp-${var.env}"
  depends_on = [google_firebase_project.default]
}

# Domínio customizado (ex: app.homolog.turni.com.br).
# Firebase verifica a posse via CNAME que já deve estar no Cloud DNS antes deste apply.
resource "google_firebase_hosting_custom_domain" "webapp" {
  count         = var.custom_domain != null ? 1 : 0
  provider      = google-beta
  project       = var.project_id
  site_id       = google_firebase_hosting_site.webapp.site_id
  custom_domain = var.custom_domain
  depends_on    = [google_firebase_hosting_site.webapp]
}

# ── Sites adicionais (landing, www-redirect) ──────────────────────────────────
# Coexistem com o WebApp no mesmo projeto, sem cruzamento (sites e tags distintos — ADR-012 §8).
resource "google_firebase_hosting_site" "additional" {
  for_each   = var.additional_sites
  provider   = google-beta
  project    = var.project_id
  site_id    = each.value.site_id
  depends_on = [google_firebase_project.default]
}

# Domínio customizado de cada site adicional (apex, www, landing.homolog).
# O apex (turni.com.br) usa A/AAAA no Cloud DNS; subdomínios usam CNAME. O recurso de
# custom_domain do Firebase é o mesmo nos dois casos — o tipo do registro fica no módulo dns.
resource "google_firebase_hosting_custom_domain" "additional" {
  for_each      = { for k, v in var.additional_sites : k => v if v.custom_domain != null }
  provider      = google-beta
  project       = var.project_id
  site_id       = google_firebase_hosting_site.additional[each.key].site_id
  custom_domain = each.value.custom_domain
  depends_on    = [google_firebase_hosting_site.additional]
}
