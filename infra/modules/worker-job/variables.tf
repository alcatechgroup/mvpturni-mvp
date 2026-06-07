variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "southamerica-east1"
}

variable "env" {
  type        = string
  description = "homolog | prod"
}

# ── Identidade do Job (STORY-073) ────────────────────────────────────────────
# Defaults preservam os nomes originais do worker (IDR-016) — instanciar com
# name = "scheduler" cria o par turni-scheduler-job-<env> / turni-scheduler-scheduler-<env>
# sem tocar o estado do worker existente.
variable "name" {
  type        = string
  description = "Papel do Job nos nomes dos recursos: turni-<name>-job-<env> e turni-<name>-scheduler-<env>."
  default     = "worker"
}

variable "sa_account_short" {
  type        = string
  description = "Abreviação no account_id da SA do Scheduler (turni-<short>-sched-<env>; account_id tem limite de 30 chars)."
  default     = "wrk"
}

variable "image" {
  type        = string
  description = "URI completo da imagem da api no Artifact Registry (worker usa o mesmo código). O pipeline gerencia a imagem em runtime (ignore_changes)."
}

variable "service_account_email" {
  type        = string
  description = "SA de runtime do Job (turni-apps) — já tem cloudsql.client + secretmanager.secretAccessor + logging.logWriter."
}

variable "cloudsql_connection_name" {
  type        = string
  description = "project:region:instance — montado como socket via volumes.cloud_sql_instance."
}

# Direct VPC egress — necessário para alcançar o Cloud SQL de IP privado (IDR-007).
variable "vpc_network" {
  type = string
}

variable "vpc_subnetwork" {
  type = string
}

variable "command" {
  type        = list(string)
  description = "Comando + args do container. Default = worker da fila; a instância scheduler (STORY-073) sobrescreve com [\"php\", \"artisan\", \"schedule:run\"]."
  default = [
    "php", "artisan", "queue:work", "database",
    "--stop-when-empty", "--tries=3", "--sleep=2", "--timeout=60",
  ]
}

variable "env_vars" {
  type    = map(string)
  default = {}
}

variable "secret_env_vars" {
  type = map(object({
    secret  = string
    version = string
  }))
  default = {}
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "task_timeout" {
  type        = string
  description = "Timeout da task do Job (s). Folga sobre o --timeout=60 do queue:work + drenagem da fila."
  default     = "600s"
}

variable "max_retries" {
  type        = number
  description = "Retentativas da task do Job. 0 = a janela seguinte do Scheduler reprocessa (queue:work já tem --tries)."
  default     = 0
}

# ── Scheduler ────────────────────────────────────────────────────────────────
variable "schedule" {
  type        = string
  description = "Cron do Cloud Scheduler que dispara o Job."
  default     = "* * * * *"
}

variable "time_zone" {
  type    = string
  default = "America/Sao_Paulo"
}

# Sobe o Cloud Scheduler PAUSADO (sem disparar o Job). Usado no prod "parado":
# o Job existe mas nunca executa → custo zero. No go-live, reaplicar com false.
variable "scheduler_paused" {
  type    = bool
  default = false
}
