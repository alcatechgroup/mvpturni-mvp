# Cloud DNS — zona turni.com.br e registros de subdomínio por ambiente.
# A zona é criada uma vez (shared entre homolog e prod); os registros são adicionados
# por env conforme os CNAMEs ficam disponíveis.
# Fase 1: create_zone=true → apply → pegar NS records → configurar no registro.br.
# Fase 2: preencher webapp_* e api_* → apply novamente para criar os CNAMEs.
# Admin não tem registro DNS público — acesso via URL direta do Cloud Run.

resource "google_dns_managed_zone" "turni" {
  count       = var.create_zone ? 1 : 0
  project     = var.project_id
  name        = "turni-com-br"
  dns_name    = "turni.com.br."
  description = "Zona DNS principal do Turni"
}

# app.homolog.turni.com.br → Firebase Hosting
resource "google_dns_record_set" "webapp" {
  count        = var.webapp_subdomain != null && var.webapp_cname_target != null ? 1 : 0
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.webapp_subdomain}."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["${var.webapp_cname_target}."]
}

# api.homolog.turni.com.br → Cloud Run via domain mapping (ghs.googlehosted.com)
resource "google_dns_record_set" "api" {
  count        = var.api_subdomain != null && var.api_cname_target != null ? 1 : 0
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.api_subdomain}."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["${var.api_cname_target}."]
}

# ── Landing institucional (EPIC-006 / ADR-012) ───────────────────────────────

# landing.homolog.turni.com.br → Firebase Hosting (site da landing homolog)
resource "google_dns_record_set" "landing" {
  count        = var.landing_subdomain != null && var.landing_cname_target != null ? 1 : 0
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.landing_subdomain}."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["${var.landing_cname_target}."]
}

# apex turni.com.br → Firebase Hosting (registros A/AAAA — primeiro uso de apex na zona).
# Os IPs vêm do Firebase Hosting ("connect domain") — confirmar em go-public pelo
# required_dns_updates do google_firebase_hosting_custom_domain (ver runbook STORY-032).
# Aplicado somente no go-public (gated por landing_prod_enabled no env prod).
resource "google_dns_record_set" "apex_a" {
  count        = var.apex_domain != null && length(var.apex_a_records) > 0 ? 1 : 0
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.apex_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = var.apex_a_records
}

resource "google_dns_record_set" "apex_aaaa" {
  count        = var.apex_domain != null && length(var.apex_aaaa_records) > 0 ? 1 : 0
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.apex_domain}."
  type         = "AAAA"
  ttl          = 300
  rrdatas      = var.apex_aaaa_records
}

# www.turni.com.br → micro-site de redirect 301 para o apex (ADR-012 §6 fallback estável
# em Terraform; o redirect em si fica no firebase.json do micro-site — STORY-031).
resource "google_dns_record_set" "www" {
  count        = var.www_subdomain != null && var.www_cname_target != null ? 1 : 0
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.www_subdomain}."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["${var.www_cname_target}."]
}
