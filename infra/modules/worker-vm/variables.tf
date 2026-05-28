variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "southamerica-east1"
}

variable "env" {
  type = string
}

variable "image" {
  type        = string
  description = "URI da imagem da api (worker usa o mesmo código)"
}

variable "service_account_email" {
  type = string
}

variable "cloudsql_connection_name" {
  type = string
}

variable "vpc_network" {
  type = string
}

variable "subnetwork" {
  type = string
}
