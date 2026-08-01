variable "project_id" {
  description = "ID do projeto GCP FoodHub"
  type        = string
  default     = "foodhub-87e0c"
}

variable "region" {
  description = "Região GCP"
  type        = string
  default     = "southamerica-east1"
}

variable "zone" {
  description = "Zona da VPS"
  type        = string
  default     = "southamerica-east1-c"
}

variable "alert_email" {
  description = "E-mail de alertas e contato do ACME"
  type        = string
}

variable "enable_uptime_checks" {
  description = "Liga uptime checks do Cloud Monitoring (cobrados — desligados por padrão)"
  type        = bool
  default     = false
}

# ── Cloudflare ───────────────────────────────────────────────────────────────
variable "cloudflare_token" {
  description = "Token da API Cloudflare com Zone:DNS:Edit em turni.com.br. Vem do .env da raiz via TF_VAR_cloudflare_token. SEGREDO."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "ID da zona turni.com.br"
  type        = string
  default     = "d9d4c3788151f6f7683f261ef35d2efb"
}

variable "mail_dkim_value" {
  description = "DKIM público do Resend para mail-homolog.turni.com.br (dado público de DNS — STORY-021)"
  type        = string
  default     = null
}

# ── Segredos das aplicações ──────────────────────────────────────────────────
variable "app_key_api" {
  description = "Laravel APP_KEY da api (base64:...)"
  type        = string
  sensitive   = true
}

variable "app_key_admin" {
  description = "Laravel APP_KEY do admin (base64:...)"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Senha do Postgres da VPS"
  type        = string
  sensitive   = true
}

variable "resend_api_key" {
  description = "Chave da API do Resend (ADR-011 / STORY-021 CA-2)"
  type        = string
  sensitive   = true
}

variable "pagarme_secret_key" {
  description = "Bearer do fake de pagamento (contract.md §auth), compartilhado entre fake e api/worker"
  type        = string
  sensitive   = true
}

variable "pagarme_webhook_secret" {
  description = "Segredo HMAC do webhook do fake de pagamento (ADR-016 e)"
  type        = string
  sensitive   = true
}

variable "pix_falha_chave_key" {
  description = "IDR-028 — chave de criptografia da chave Pix do snapshot de pix_falhas (base64:<32 bytes>)"
  type        = string
  sensitive   = true
}

# ── Fake de pagamento ────────────────────────────────────────────────────────
variable "pagarme_mock_pix_resultado" {
  description = "Cenário do Pix no fake: sucesso | falha (STORY-065 CA-5)"
  type        = string
  default     = "sucesso"
}

variable "pagarme_mock_pix_sla_segundos" {
  description = "Atraso do webhook de Pix no fake (STORY-065 CA-7)"
  type        = number
  default     = 30
}
