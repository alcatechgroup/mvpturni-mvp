# Variáveis do ambiente STAGE co-localizado no projeto turni-homol (ver stage.tf).
# Só os valores que DIFEREM do homol (segredos próprios + two-phase). Recursos
# compartilhados (region, project_id, github_repo, alert_email, imagens, flags do
# pagarme-mock) reusam as variáveis do homol (variables.tf).

variable "db_password_stage" {
  description = "Senha do usuário Postgres turni_stage (database turni_stage no instance compartilhado)"
  type        = string
  sensitive   = true
}

variable "app_key_api_stage" {
  description = "Laravel APP_KEY da api de stage (base64:...)"
  type        = string
  sensitive   = true
}

variable "app_key_admin_stage" {
  description = "Laravel APP_KEY do admin de stage (base64:...)"
  type        = string
  sensitive   = true
}

variable "resend_api_key_stage" {
  description = "Chave da API do Resend para stage (ADR-011)"
  type        = string
  sensitive   = true
}

variable "pagarme_secret_key_stage" {
  description = "Bearer do fake de pagamento de stage (compartilhado fake↔api/worker de stage)"
  type        = string
  sensitive   = true
}

variable "pagarme_webhook_secret_stage" {
  description = "Segredo HMAC do webhook do fake de pagamento de stage"
  type        = string
  sensitive   = true
}

variable "pix_falha_chave_key_stage" {
  description = "Chave de criptografia da chave Pix do snapshot pix_falhas (stage); base64:<32 bytes>"
  type        = string
  sensitive   = true
}

variable "mail_dkim_value_stage" {
  description = "DKIM público do Resend para mail.stage.turni.com.br (dado público de DNS). null = sem registro DKIM."
  type        = string
  default     = null
}

# Two-phase (igual ao homol): o fake precisa do URL público da api de stage para o
# webhook, mas a api referencia a uri do fake (ciclo). 1º apply vazio; depois preencher
# com `terraform output api_url_stage` e reaplicar.
variable "api_public_url_stage" {
  description = "URL público do Cloud Run da api de stage — alimenta o PAGARME_WEBHOOK_TARGET do fake de stage. Two-phase."
  type        = string
  default     = ""
}
