variable "project_id" {
  description = "ID do projeto GCP (FoodHub — compartilhado com outras aplicações)"
  type        = string
}

variable "env" {
  description = "Ambiente de INFRA (homolog | staging | prod). Entra no prefixo de todo nome de recurso."
  type        = string

  validation {
    condition     = contains(["homolog", "staging", "prod"], var.env)
    error_message = "env deve ser homolog, staging ou prod."
  }
}

variable "business_env" {
  description = <<-EOT
    Ambiente de NEGÓCIO exposto às apps (TURNI_ENV). Distinto de `env` porque APP_ENV é
    sempre "production" (otimizações do Laravel) — é este valor que liga o banner
    "Ambiente de teste — pagamentos simulados" no Backoffice (STORY-075 / PDR-017).
    Em prod deve ser "production", justamente para o banner NÃO aparecer.
  EOT
  type        = string
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

variable "extra_labels" {
  description = "Labels adicionais aplicadas aos recursos do ambiente"
  type        = map(string)
  default     = {}
}

# ── Rede ─────────────────────────────────────────────────────────────────────
variable "subnet_cidr" {
  description = "CIDR /24 exclusivo do ambiente"
  type        = string
}

variable "enable_flow_logs" {
  description = "Liga VPC Flow Logs (custo de ingestão)"
  type        = bool
  default     = false
}

# ── VPS ──────────────────────────────────────────────────────────────────────
variable "machine_type" {
  description = "Tipo de máquina da VPS"
  type        = string
  default     = "e2-small"
}

variable "boot_disk_size_gb" {
  description = "Disco de boot (SO + imagens Docker)"
  type        = number
  default     = 20
}

variable "data_disk_size_gb" {
  description = "Disco de dados (Postgres + storage das apps)"
  type        = number
  default     = 20
}

variable "data_mount_point" {
  description = "Ponto de montagem do disco de dados"
  type        = string
  default     = "/var/lib/turni"
}

variable "network_tier" {
  description = "PREMIUM (backbone Google) ou STANDARD (mais barato)"
  type        = string
  default     = "PREMIUM"
}

variable "install_ops_agent" {
  description = "Instala o Ops Agent na VPS (logs + métricas — ADR-008)"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Retenção dos dumps no bucket de backups"
  type        = number
  default     = 30
}

variable "runtime_source_dir" {
  description = "Caminho do runtime da VPS no repo (normalmente ../../vps)"
  type        = string
}

variable "deployer_members" {
  description = "Membros IAM autorizados a fazer deploy nesta VPS (a SA do CI)"
  type        = list(string)
  default     = []
}

# ── Imagens ──────────────────────────────────────────────────────────────────
variable "registry_url" {
  description = "URL base do Artifact Registry compartilhado (output do env shared)"
  type        = string
}

variable "default_image_tag" {
  description = "Tag usada no primeiro boot, antes do primeiro deploy do pipeline"
  type        = string
  default     = "latest"
}

# ── DNS / hosts ──────────────────────────────────────────────────────────────
variable "dns_zone_id" {
  description = "ID da zona turni.com.br na Cloudflare"
  type        = string
}

variable "dns_zone_name" {
  description = "Nome da zona (turni.com.br)"
  type        = string
  default     = "turni.com.br"
}

variable "dns_proxied" {
  description = "Passa pelo proxy da Cloudflare. Desligar quebra o firewall, que só aceita as faixas da Cloudflare."
  type        = bool
  default     = true
}

variable "hosts" {
  description = <<-EOT
    FQDNs do ambiente, ACHATADOS em um nível (ADR-021 §c).
    Ex. homolog: { webapp = "app-homolog.turni.com.br", admin = "admin-homolog.turni.com.br",
                   api = "api-homolog.turni.com.br", landing = "homolog.turni.com.br" }
  EOT
  type = object({
    webapp  = string
    admin   = string
    api     = string
    landing = string
  })
}

variable "mail_sender_host" {
  description = "Rótulo do host remetente do e-mail, relativo à zona (ex.: mail-homolog)"
  type        = string
}

variable "mail_from_name" {
  description = "Nome exibido no remetente"
  type        = string
  default     = "Turni"
}

variable "mail_dkim_value" {
  description = "DKIM público fornecido pelo Resend (dado público de DNS)"
  type        = string
  default     = null
}

variable "acme_email" {
  description = "E-mail de contato do ACME (avisos de expiração de certificado)"
  type        = string
}

# ── Banco ────────────────────────────────────────────────────────────────────
variable "db_name" {
  description = "Nome do banco no Postgres da VPS"
  type        = string
  default     = "turni"
}

variable "db_user" {
  description = "Usuário do banco"
  type        = string
  default     = "turni"
}

# ── Segredos ─────────────────────────────────────────────────────────────────
variable "secrets" {
  description = "Mapa papel => valor entregue ao módulo secrets (ver infra/README.md)"
  type        = map(string)
  sensitive   = true
}

# ── Gateway de pagamento ─────────────────────────────────────────────────────
variable "enable_payment_fake" {
  description = "Sobe o fake de pagamento junto da stack (PDR-017 / ADR-016 d). NUNCA em prod."
  type        = bool
  default     = false
}

variable "pagarme_mock_pix_resultado" {
  description = "Cenário do Pix no fake: sucesso | falha (STORY-065 CA-5)"
  type        = string
  default     = "sucesso"

  validation {
    condition     = contains(["sucesso", "falha"], var.pagarme_mock_pix_resultado)
    error_message = "pagarme_mock_pix_resultado deve ser `sucesso` ou `falha`."
  }
}

variable "pagarme_mock_pix_sla_segundos" {
  description = "Atraso do webhook de Pix no fake, em segundos (STORY-065 CA-7)"
  type        = number
  default     = 30
}

# ── Observabilidade ──────────────────────────────────────────────────────────
variable "alert_email" {
  description = "E-mail que recebe os alertas"
  type        = string
}

variable "enable_uptime_checks" {
  description = "Liga uptime checks (cobrados)"
  type        = bool
  default     = false
}

variable "enable_vps_alerts" {
  description = "Liga alertas de memória/disco da VPS"
  type        = bool
  default     = true
}
