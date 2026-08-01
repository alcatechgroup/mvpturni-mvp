variable "project_id" {
  description = "ID do projeto GCP que hospeda o ambiente (FoodHub)"
  type        = string
}

variable "env" {
  description = "Ambiente (homolog | staging | prod)"
  type        = string
}

variable "name_prefix" {
  description = "Prefixo dos nomes dos recursos (convenção: turni-<env> — ver infra/README.md)"
  type        = string
}

variable "region" {
  description = "Região GCP"
  type        = string
}

variable "zone" {
  description = "Zona da instância e do disco de dados"
  type        = string
}

variable "labels" {
  description = "Labels aplicadas a todos os recursos que as suportam"
  type        = map(string)
}

variable "machine_type" {
  description = "Tipo de máquina. e2-small (2 GB) é o piso praticável: abaixo disso o Postgres + 2 PHP-FPM + worker vivem em swap."
  type        = string
  default     = "e2-small"
}

variable "boot_image" {
  description = "Imagem de boot (família Debian 12 — base do startup script)"
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "boot_disk_size_gb" {
  description = "Tamanho do disco de boot (só SO + imagens Docker)"
  type        = number
  default     = 20
}

variable "data_disk_size_gb" {
  description = "Tamanho do disco de dados (Postgres + storage das apps)"
  type        = number
  default     = 20
}

variable "data_disk_type" {
  description = "Tipo do disco de dados (pd-balanced equilibra IOPS e custo para o Postgres)"
  type        = string
  default     = "pd-balanced"
}

variable "data_mount_point" {
  description = "Ponto de montagem do disco de dados na VPS"
  type        = string
  default     = "/var/lib/turni"
}

variable "app_dir" {
  description = "Diretório do runtime na VPS (compose, Caddyfile, scripts, .env)"
  type        = string
  default     = "/opt/turni"
}

variable "network_self_link" {
  description = "Self link da VPC (módulo network)"
  type        = string
}

variable "subnetwork_self_link" {
  description = "Self link da subnet (módulo network)"
  type        = string
}

variable "network_tags" {
  description = "Network tags da instância (as que casam com as regras de firewall)"
  type        = list(string)
}

variable "network_tier" {
  description = "Nível de rede do IP externo: PREMIUM (backbone Google) ou STANDARD (mais barato)"
  type        = string
  default     = "PREMIUM"

  validation {
    condition     = contains(["PREMIUM", "STANDARD"], var.network_tier)
    error_message = "network_tier deve ser PREMIUM ou STANDARD."
  }
}

variable "accessible_secret_ids" {
  description = "secret_id dos segredos do Secret Manager que a VPS deste ambiente pode ler"
  type        = list(string)
  default     = []
}

variable "deployer_members" {
  description = "Membros IAM que fazem deploy nesta VPS (ex.: [\"serviceAccount:turni-ci@...\"]) — ganham serviceAccountUser sobre a SA da instância e acesso ao túnel IAP dela"
  type        = list(string)
  default     = []
}

variable "runtime_source_dir" {
  description = "Diretório do repo com o runtime da VPS publicado no bucket de config (infra/vps)"
  type        = string
}

variable "runtime_env_content" {
  description = "Conteúdo do runtime.env NÃO-secreto gerado pelo Terraform (hosts, registry, flags)"
  type        = string
}

variable "backup_retention_days" {
  description = "Dias de retenção dos dumps no bucket de backups"
  type        = number
  default     = 30
}

variable "install_ops_agent" {
  description = "Instala o Ops Agent (métricas de memória/disco e logs dos containers no Cloud Logging — ADR-008)"
  type        = bool
  default     = true
}
