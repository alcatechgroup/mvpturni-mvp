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

# Two-phase (igual ao padrão do DNS): o fake de pagamento precisa do URL público do
# Cloud Run da api para destinar o webhook, mas o api referencia a uri do fake (ciclo).
# 1º apply: vazio → webhook aponta para placeholder. Após o api subir, preencher com
# `terraform output api_url` e reaplicar. O hash do run.app muda por projeto, então não
# dá para hardcodar (era o caso antes, com o hash do turni-mvp).
variable "api_public_url" {
  description = "URL público do Cloud Run da api (ex: https://turni-api-homolog-XXXX.run.app) — alimenta o PAGARME_WEBHOOK_TARGET do fake. Two-phase."
  type        = string
  default     = ""
}

variable "mail_dkim_value" {
  description = "DKIM público do Resend para mail.stage.turni.com.br (dado público de DNS — STORY-021)"
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

variable "pagarme_mock_pix_resultado" {
  description = "STORY-065 (CA-5) — cenário do Pix no fake: `sucesso` | `falha` (falha emite webhook transfer.failed determinístico p/ validar a fila 'Pix com falha' do admin em homolog)"
  type        = string
  default     = "sucesso"

  validation {
    condition     = contains(["sucesso", "falha"], var.pagarme_mock_pix_resultado)
    error_message = "pagarme_mock_pix_resultado deve ser `sucesso` ou `falha`."
  }
}

variable "pagarme_mock_pix_sla_segundos" {
  description = "STORY-065 (CA-7 / PDR-017) — atraso do webhook do Pix no fake, em segundos (~30 simula a promessa 'Pix em ≤ 15 min' sem segurar a resposta HTTP)"
  type        = number
  default     = 30
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

variable "pix_falha_chave_key" {
  description = "STORY-065 (IDR-028) — chave de criptografia da chave Pix do snapshot de pix_falhas, compartilhada api/worker/admin; formato base64:<32 bytes>. SEGREDO — gerar valor aleatório (php -r \"echo 'base64:'.base64_encode(random_bytes(32));\"); nunca em git versionado."
  type        = string
  sensitive   = true
}
