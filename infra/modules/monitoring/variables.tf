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

variable "enable_uptime_checks" {
  type        = bool
  default     = false
  description = <<-EOT
    Liga os uptime checks HTTP (/health das interfaces + raiz do webapp) e a alert
    policy de indisponibilidade que depende deles. DESLIGADO por padrão: cada check roda
    de 6 localizações globais e o volume estourava o free tier de 1M execuções/mês do
    Cloud Monitoring, gerando custo relevante em ambiente não-produtivo. Religar só quando
    houver necessidade real de SLA de disponibilidade (e, aí, revisar período/região).
  EOT
}
