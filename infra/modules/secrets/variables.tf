variable "project_id" {
  type = string
}

variable "env" {
  type = string
}

variable "app_key_api" {
  type      = string
  sensitive = true
}

variable "app_key_admin" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "resend_api_key" {
  type        = string
  sensitive   = true
  description = "Chave da API do Resend (ADR-011). Valor fora do git — via tfvars não versionado / SOPS."
}
