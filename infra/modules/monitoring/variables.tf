variable "project_id" {
  description = "ID do projeto GCP (FoodHub)"
  type        = string
}

variable "env" {
  description = "Ambiente (homolog | staging | prod) — entra no nome das métricas e no log_id"
  type        = string
}

variable "alert_email" {
  description = "E-mail que recebe os alertas do ambiente"
  type        = string
}

variable "enable_uptime_checks" {
  description = "Liga os uptime checks (cobrados pelo Cloud Monitoring; desligados por padrão desde a revisão de custo)"
  type        = bool
  default     = false
}

variable "uptime_targets" {
  description = "Alvos dos uptime checks: rótulo => { host, path }"
  type = map(object({
    host = string
    path = string
  }))
  default = {}
}

variable "enable_vps_alerts" {
  description = "Liga os alertas de memória e disco da VPS (dependem do Ops Agent instalado)"
  type        = bool
  default     = true
}

variable "memory_threshold_percent" {
  description = "Percentual de memória usada que dispara alerta"
  type        = number
  default     = 90
}

variable "disk_threshold_percent" {
  description = "Percentual de disco usado que dispara alerta"
  type        = number
  default     = 85
}

variable "metric_propagation_delay" {
  description = "Espera entre criar as log-based metrics e as alert policies que as consomem. O Cloud Monitoring leva alguns minutos para reconhecer métrica nova; sem isso o primeiro apply do ambiente falha com 404."
  type        = string
  default     = "240s"
}
