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
  description = "FQDN do webapp (ex: app.homolog.turni.com.br) — omitir até ter o CNAME target"
}

variable "webapp_cname_target" {
  type        = string
  default     = null
  description = "Target CNAME para o Firebase Hosting (ex: turni-webapp-homolog.web.app)"
}

variable "api_subdomain" {
  type        = string
  default     = null
  description = "FQDN da API — omitir até ter o IP do LB"
}

variable "api_ip" {
  type        = string
  default     = null
  description = "IP estático do LB da API — omitir enquanto LB não estiver provisionado"
}

variable "admin_subdomain" {
  type        = string
  default     = null
  description = "FQDN do admin — omitir até ter o IP do LB"
}

variable "admin_ip" {
  type        = string
  default     = null
  description = "IP estático do LB do admin — omitir enquanto LB não estiver provisionado"
}
