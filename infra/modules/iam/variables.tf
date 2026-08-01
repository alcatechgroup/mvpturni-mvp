variable "project_id" {
  description = "ID do projeto GCP (FoodHub)"
  type        = string
}

variable "github_repo" {
  description = "Repositório GitHub autorizado, no formato owner/repo"
  type        = string
}

variable "ci_account_id" {
  description = "account_id da service account do CI (prefixo de aplicação: o projeto é compartilhado)"
  type        = string
  default     = "turni-ci"
}

variable "pool_id" {
  description = "ID do Workload Identity Pool (prefixado por aplicação)"
  type        = string
  default     = "turni-github"
}

variable "provider_id" {
  description = "ID do provider OIDC dentro do pool"
  type        = string
  default     = "turni-github-oidc"
}
