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
