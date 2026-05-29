variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "southamerica-east1"
}

variable "app" {
  type        = string
  description = "api | admin"
}

variable "env" {
  type        = string
  description = "homolog | prod"
}

variable "image" {
  type        = string
  description = "URI completo da imagem no Artifact Registry"
}

variable "service_account_email" {
  type = string
}

variable "cloudsql_connection_name" {
  type = string
}

variable "ingress" {
  type    = string
  default = "INGRESS_TRAFFIC_ALL"
}

variable "allow_unauthenticated" {
  type    = bool
  default = false
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 3
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

# Direct VPC egress — necessário para alcançar Cloud SQL de IP privado (STORY-016).
# Sem isto o connector cloudsql-instances dá "timeout" no socket. null = sem VPC.
variable "vpc_network" {
  type    = string
  default = null
}

variable "vpc_subnetwork" {
  type    = string
  default = null
}

variable "env_vars" {
  type    = map(string)
  default = {}
}

variable "secret_env_vars" {
  type = map(object({
    secret  = string
    version = string
  }))
  default = {}
}
