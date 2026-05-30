variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "southamerica-east1"
}

variable "env" {
  type        = string
  description = "homolog | prod"
}

variable "instance_name" {
  type        = string
  description = "Nome da instância Cloud SQL a controlar"
}
