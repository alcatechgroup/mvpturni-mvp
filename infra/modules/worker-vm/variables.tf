variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "southamerica-east1"
}

variable "env" {
  type = string
}

variable "image" {
  type        = string
  description = "URI da imagem da api (worker usa o mesmo código)"
}

variable "service_account_email" {
  type = string
}

variable "cloudsql_connection_name" {
  type        = string
  description = "Legado (socket). O worker conecta por IP privado (db_private_ip); mantido por compat."
}

variable "db_private_ip" {
  type        = string
  description = "IP privado do Cloud SQL na VPC — o worker conecta direto (mesma VPC), sem proxy."
}

variable "vpc_network" {
  type = string
}

variable "subnetwork" {
  type = string
}

# ── Segredos (Secret Manager) buscados no boot da VM (STORY-021) ──────────────
# A SA da VM tem roles/secretmanager.secretAccessor (módulo iam). O cloud-init
# busca os valores em runtime e escreve um env-file em tmpfs — nunca em metadata.

variable "app_key_secret_id" {
  type        = string
  description = "secret_id do APP_KEY da api no Secret Manager."
}

variable "db_password_secret_id" {
  type        = string
  description = "secret_id da senha do banco no Secret Manager."
}

variable "resend_api_key_secret_id" {
  type        = string
  description = "secret_id da chave do Resend no Secret Manager (ADR-011)."
}

variable "mail_mailer" {
  type    = string
  default = "resend"
}

variable "mail_from_address" {
  type = string
}

variable "mail_from_name" {
  type    = string
  default = "Turni"
}
