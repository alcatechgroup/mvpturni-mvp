variable "project_id" {
  description = "ID do projeto GCP FoodHub"
  type        = string
  default     = "foodhub-87e0c"
}

variable "region" {
  description = "Região GCP principal"
  type        = string
  default     = "southamerica-east1"
}

variable "github_repo" {
  description = "Repositório GitHub autorizado a assumir a SA do CI (owner/repo)"
  type        = string
  default     = "alcatechgroup/mvpturni-mvp"
}
