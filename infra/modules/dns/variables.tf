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
  description = "FQDN do webapp (ex: app.homolog.turni.com.br)"
}

variable "webapp_cname_target" {
  type        = string
  description = "Target CNAME para o Firebase Hosting"
}

variable "api_subdomain" {
  type = string
}

variable "api_ip" {
  type = string
}

variable "admin_subdomain" {
  type = string
}

variable "admin_ip" {
  type = string
}
