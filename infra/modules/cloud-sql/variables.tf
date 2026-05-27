variable "project_id" { type = string }
variable "region"     { type = string; default = "southamerica-east1" }
variable "env"        { type = string; description = "homolog | prod" }

variable "db_tier" {
  type    = string
  default = "db-f1-micro"  # ~R$0 com créditos; ajustar para prod
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "vpc_network" {
  type        = string
  description = "Self-link da VPC onde a instância será criada (private service connection)"
}
