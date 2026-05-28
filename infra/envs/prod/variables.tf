variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "southamerica-east1"
}

variable "github_repo" {
  type = string
}

variable "alert_email" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "app_key_api" {
  type      = string
  sensitive = true
}

variable "app_key_admin" {
  type      = string
  sensitive = true
}

variable "api_image" {
  type    = string
  default = ""
}

variable "admin_image" {
  type    = string
  default = ""
}

# ── Landing institucional (EPIC-006 / ADR-012) ───────────────────────────────
# Gate de go-public: tudo da landing prod (sites Firebase + apex/www no DNS) fica
# codificado mas NÃO aplicado enquanto false. O comercial autoriza o go-public via
# PR que vira esta flag true (ver runbook STORY-032). Default false.
variable "landing_prod_enabled" {
  type        = bool
  default     = false
  description = "Liga os sites Firebase e registros DNS apex/www da landing em produção (go-public)"
}

variable "firebase_apex_a_records" {
  type        = list(string)
  default     = ["199.36.158.100"]
  description = "IPs IPv4 do Firebase Hosting para o apex turni.com.br — confirmar no go-public via required_dns_updates do custom domain / console Firebase"
}

variable "firebase_apex_aaaa_records" {
  type        = list(string)
  default     = []
  description = "IPs IPv6 do Firebase Hosting para o apex (opcional — preencher no go-public se aplicável)"
}
