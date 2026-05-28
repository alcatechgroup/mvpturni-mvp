variable "project_id" { type = string }
variable "env"        { type = string }

variable "custom_domain" {
  type        = string
  default     = null
  description = "Domínio customizado para o Firebase Hosting (ex: app.homolog.turni.com.br)"
}
