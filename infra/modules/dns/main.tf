# Cloud DNS — zona turni.com.br e registros de subdomínio por ambiente.
# A zona é criada uma vez (shared entre homolog e prod); os registros são adicionados
# por env conforme os IPs/CNAMEs ficam disponíveis (LBs, Firebase custom domain).
# Fase 1: create_zone=true → apply → pegar NS records → configurar no registro.br.
# Fase 2: preencher as variáveis *_subdomain/*_ip/*_cname_target → apply novamente.

resource "google_dns_managed_zone" "turni" {
  count       = var.create_zone ? 1 : 0
  project     = var.project_id
  name        = "turni-com-br"
  dns_name    = "turni.com.br."
  description = "Zona DNS principal do Turni"
}

resource "google_dns_record_set" "webapp" {
  count        = var.webapp_subdomain != null && var.webapp_cname_target != null ? 1 : 0
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.webapp_subdomain}."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["${var.webapp_cname_target}."]
}

resource "google_dns_record_set" "api" {
  count        = var.api_subdomain != null && var.api_ip != null ? 1 : 0
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.api_subdomain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.api_ip]
}

resource "google_dns_record_set" "admin" {
  count        = var.admin_subdomain != null && var.admin_ip != null ? 1 : 0
  project      = var.project_id
  managed_zone = var.dns_zone_name
  name         = "${var.admin_subdomain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.admin_ip]
}
