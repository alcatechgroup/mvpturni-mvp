variable "project_id" { type = string }
variable "env" { type = string }

variable "custom_domain" {
  type        = string
  default     = null
  description = "Domínio customizado do site principal (WebApp), ex: app.homolog.turni.com.br"
}

variable "additional_sites" {
  description = <<-EOT
    Sites Firebase Hosting extras no mesmo projeto GCP, indexados por chave estável
    (ex: "landing", "www_redirect"). Cada site tem site_id e um custom_domain opcional.
    Vazio por padrão — o WebApp não cria nenhum site adicional.
  EOT
  type = map(object({
    site_id       = string
    custom_domain = optional(string)
  }))
  default = {}
}
