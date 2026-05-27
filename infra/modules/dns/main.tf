# Cloud DNS — zona turni.com.br e registros de subdomínio por ambiente.
# A zona é criada uma vez (shared entre homolog e prod); os registros são por env.

resource "google_dns_managed_zone" "turni" {
  count       = var.create_zone ? 1 : 0
  project     = var.project_id
  name        = "turni-com-br"
  dns_name    = "turni.com.br."
  description = "Zona DNS principal do Turni"
}

# Subdomínios de homologação: app.homolog / admin.homolog / api.homolog
resource "google_dns_record_set" "webapp" {
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.webapp_subdomain}."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = [var.webapp_cname_target]
}

resource "google_dns_record_set" "api" {
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.api_subdomain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.api_ip]
}

resource "google_dns_record_set" "admin" {
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.admin_subdomain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.admin_ip]
}
