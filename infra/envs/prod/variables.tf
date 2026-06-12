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

# Chave do Resend (ADR-011). O módulo secrets passou a exigi-la quando homolog ganhou
# e-mail transacional (STORY-021) e este scaffold ficou para trás — `terraform validate`
# quebrava. Detectado/corrigido na STORY-073.
variable "resend_api_key" {
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

# ── Postura "prod parado" (3 projetos independentes) ─────────────────────────
# false (default) = projeto turni-prod aplicado mas PARADO (custo ~zero): Cloud Run
# min=0, worker/scheduler com Cloud Scheduler pausado, monitoring desligado. SQL sobe
# STOPPED (activation_policy=NEVER no módulo). No go-live (EPIC-006), virar true e
# reaplicar — e ligar o SQL manualmente (gcloud sql instances patch ... ALWAYS).
variable "prod_live_enabled" {
  type        = bool
  default     = false
  description = "true = liga os recursos de prod (min_instances=1, schedulers ativos, monitoring). Default false = parado."
}

# Delegação de subdomínio: mapa FQDN → nameservers das zonas filhas, publicado como
# registros NS na zona apex turni.com.br. Preencher com os `dns_name_servers` de:
#   homolog.turni.com.br → output do env homolog (projeto turni-homol)
#   stage.turni.com.br   → output do env stage   (projeto turni-stage)
variable "delegations" {
  type        = map(list(string))
  default     = {}
  description = "Ex: { \"homolog.turni.com.br\" = [\"ns-cloud-a1...\", ...], \"stage.turni.com.br\" = [...] }"
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
  description = "IPs IPv4 do Firebase Hosting para o apex turni.com.br — valor atual do Firebase (confirmado live em 2026-06). Reconfirmar via required_dns_updates do custom domain / console Firebase se mudar."
}

variable "firebase_apex_aaaa_records" {
  type        = list(string)
  default     = []
  description = "IPs IPv6 do Firebase Hosting para o apex (opcional — preencher no go-public se aplicável)"
}
