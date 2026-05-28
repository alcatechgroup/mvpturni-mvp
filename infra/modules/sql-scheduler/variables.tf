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

variable "worker_instance_name" {
  type        = string
  description = "Nome da instância GCE do worker a controlar"
}

variable "worker_zone" {
  type        = string
  description = "Zona da instância GCE do worker (ex: southamerica-east1-a)"
}
