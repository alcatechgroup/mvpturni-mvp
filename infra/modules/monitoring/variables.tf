variable "project_id" {
  type = string
}

variable "env" {
  type = string
}

variable "alert_email" {
  type        = string
  description = "E-mail para alertas de indisponibilidade"
}

variable "api_host" {
  type        = string
  description = "Hostname do API (ex: api.homolog.turni.com.br)"
}

variable "admin_host" {
  type        = string
  description = "Hostname do Admin"
}

variable "webapp_host" {
  type        = string
  description = "Hostname do WebApp"
}
