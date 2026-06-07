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

variable "db_tier" {
  type    = string
  default = "db-f1-micro"
}

# Postura de execução da instância. "ALWAYS" sobe RUNNABLE; "NEVER" sobe/mantém
# STOPPED (usado no prod "parado" — custo cai para disco + IP, sem vCPU/RAM).
# O sql-scheduler de homolog/stage também alterna este valor via REST (liga/desliga).
variable "activation_policy" {
  type    = string
  default = "ALWAYS"

  validation {
    condition     = contains(["ALWAYS", "NEVER"], var.activation_policy)
    error_message = "activation_policy deve ser ALWAYS ou NEVER."
  }
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "vpc_network" {
  type        = string
  description = "Self-link da VPC onde a instância será criada (private service connection)"
}
