variable "project_id" {
  description = "ID do projeto GCP (FoodHub)"
  type        = string
}

variable "region" {
  description = "Região do repositório"
  type        = string
  default     = "southamerica-east1"
}

variable "repository_id" {
  description = "Nome do repositório (prefixo de aplicação dentro do projeto compartilhado)"
  type        = string
  default     = "turni"
}

variable "labels" {
  description = "Labels do repositório"
  type        = map(string)
  default     = {}
}

variable "keep_versions" {
  description = "Quantas versões recentes manter por imagem"
  type        = number
  default     = 10
}

variable "untagged_ttl_days" {
  description = "Idade a partir da qual uma versão sem tag é descartada"
  type        = number
  default     = 7
}

variable "cleanup_dry_run" {
  description = "true = só reporta o que apagaria (ligar em dry-run na primeira aplicação)"
  type        = bool
  default     = false
}
