variable "project_id" {
  description = "ID do projeto GCP (ex: turni-prod-123456)"
  type        = string
}

variable "region" {
  description = "Região GCP principal"
  type        = string
  default     = "southamerica-east1"
}

variable "github_repo" {
  description = "Repositório GitHub no formato owner/repo"
  type        = string
}

variable "alert_email" {
  description = "E-mail para alertas de indisponibilidade (Alexandro)"
  type        = string
}

variable "db_password" {
  description = "Senha do banco PostgreSQL (nunca em git)"
  type        = string
  sensitive   = true
}

variable "app_key_api" {
  description = "Laravel APP_KEY para a api (base64:...)"
  type        = string
  sensitive   = true
}

variable "app_key_admin" {
  description = "Laravel APP_KEY para o admin (base64:...)"
  type        = string
  sensitive   = true
}

variable "api_image" {
  description = "Imagem inicial do Cloud Run api (atualizada pelo CI em cada deploy)"
  type        = string
  default     = "southamerica-east1-docker.pkg.dev/PROJECT_ID/turni/api:latest"
}

variable "admin_image" {
  description = "Imagem inicial do Cloud Run admin (atualizada pelo CI em cada deploy)"
  type        = string
  default     = "southamerica-east1-docker.pkg.dev/PROJECT_ID/turni/admin:latest"
}

variable "mail_dkim_value" {
  description = "DKIM público do Resend para mail.homolog.turni.com.br (dado público de DNS — STORY-021)"
  type        = string
  default     = null
}

variable "resend_api_key" {
  description = "Chave da API do Resend (ADR-011 / STORY-021 CA-2). SEGREDO — nunca em git versionado; passar via tfvars não versionado, TF_VAR_resend_api_key ou SOPS."
  type        = string
  sensitive   = true
}

variable "pagarme_mock_image" {
  description = "Imagem inicial do Cloud Run do fake de pagamento (PDR-017 / ADR-016 d; atualizada pelo CI em cada deploy)"
  type        = string
  default     = "southamerica-east1-docker.pkg.dev/PROJECT_ID/turni/pagarme-mock:latest"
}

variable "pagarme_secret_key" {
  description = "Bearer do fake de pagamento (contract.md §auth) — compartilhado entre fake e api/worker. SEGREDO — gerar valor aleatório; nunca em git versionado."
  type        = string
  sensitive   = true
}

variable "pagarme_webhook_secret" {
  description = "Segredo HMAC do webhook do fake de pagamento (ADR-016 e) — compartilhado entre fake e api/worker. SEGREDO — gerar valor aleatório; nunca em git versionado."
  type        = string
  sensitive   = true
}
