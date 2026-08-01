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

variable "machine_type" {
  description = "Tipo de máquina de produção (folga em relação ao e2-small de homolog)"
  type        = string
  default     = "e2-medium"
}

variable "data_disk_size_gb" {
  description = "Disco de dados de produção"
  type        = number
  default     = 50
}

variable "alert_email" {
  description = "E-mail de alertas e contato do ACME"
  type        = string
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
  description = "DKIM público do Resend para mail.turni.com.br (dado público de DNS)"
  type        = string
  default     = null
}

# ── Segredos das aplicações ──────────────────────────────────────────────────
# Sem os segredos do fake de pagamento: produção não sobe o fake (ADR-016 d).
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
  description = "Chave da API do Resend (ADR-011)"
  type        = string
  sensitive   = true
}

variable "pix_falha_chave_key" {
  description = "IDR-028 — chave de criptografia da chave Pix do snapshot de pix_falhas (base64:<32 bytes>)"
  type        = string
  sensitive   = true
}
