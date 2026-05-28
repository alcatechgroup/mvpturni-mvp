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
