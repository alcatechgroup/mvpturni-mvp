variable "project_id" {
  description = "ID do projeto GCP (ex: turni-prod-123456)"
  type        = string
}

variable "region" {
  description = "Região GCP principal"
  type        = string
  default     = "southamerica-east1"
}

variable "github_repo" {
  description = "Repositório GitHub no formato owner/repo"
  type        = string
}

variable "alert_email" {
  description = "E-mail para alertas de indisponibilidade (Alexandro)"
  type        = string
}

variable "db_password" {
  description = "Senha do banco PostgreSQL (nunca em git)"
  type        = string
  sensitive   = true
}

variable "app_key_api" {
  description = "Laravel APP_KEY para a api (base64:...)"
  type        = string
  sensitive   = true
}

variable "app_key_admin" {
  description = "Laravel APP_KEY para o admin (base64:...)"
  type        = string
  sensitive   = true
}

variable "api_image" {
  description = "Imagem inicial do Cloud Run api (atualizada pelo CI em cada deploy)"
  type        = string
  default     = "southamerica-east1-docker.pkg.dev/PROJECT_ID/turni/api:latest"
}

variable "admin_image" {
  description = "Imagem inicial do Cloud Run admin (atualizada pelo CI em cada deploy)"
  type        = string
  default     = "southamerica-east1-docker.pkg.dev/PROJECT_ID/turni/admin:latest"
}
