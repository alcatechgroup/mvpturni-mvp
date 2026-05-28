variable "project_id" {
  type = string
}

variable "create_zone" {
  type        = bool
  default     = false
  description = "Criar a zona DNS (somente no primeiro apply)"
}

variable "dns_zone_name" {
  type        = string
  description = "Nome da zona no Cloud DNS (ex: turni-com-br)"
}

variable "webapp_subdomain" {
  type        = string
  default     = null
  description = "FQDN do webapp (ex: app.homolog.turni.com.br)"
}

variable "webapp_cname_target" {
  type        = string
  default     = null
  description = "Target CNAME para o Firebase Hosting (ex: turni-webapp-homolog.web.app)"
}

variable "api_subdomain" {
  type        = string
  default     = null
  description = "FQDN da API (ex: api.homolog.turni.com.br)"
}

variable "api_cname_target" {
  type        = string
  default     = null
  description = "Target CNAME da API — ghs.googlehosted.com para Cloud Run domain mapping"
}

# ── Landing institucional (EPIC-006 / ADR-012) ───────────────────────────────

variable "landing_subdomain" {
  type        = string
  default     = null
  description = "FQDN da landing em homolog (ex: landing.homolog.turni.com.br)"
}

variable "landing_cname_target" {
  type        = string
  default     = null
  description = "Target CNAME do site Firebase da landing (ex: turni-landing-homolog.web.app)"
}

variable "apex_domain" {
  type        = string
  default     = null
  description = "Domínio apex servido pela landing prod (ex: turni.com.br). Registros A/AAAA."
}

variable "apex_a_records" {
  type        = list(string)
  default     = []
  description = "IPs IPv4 do Firebase Hosting para o apex (confirmar via console/required_dns_updates)"
}

variable "apex_aaaa_records" {
  type        = list(string)
  default     = []
  description = "IPs IPv6 do Firebase Hosting para o apex (opcional)"
}

variable "www_subdomain" {
  type        = string
  default     = null
  description = "FQDN do www (ex: www.turni.com.br) — CNAME para o micro-site de redirect 301"
}

variable "www_cname_target" {
  type        = string
  default     = null
  description = "Target CNAME do micro-site de redirect www (ex: turni-www-redirect-prod.web.app)"
}
