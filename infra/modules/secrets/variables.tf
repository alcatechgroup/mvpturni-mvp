variable "project_id"   { type = string }
variable "env"          { type = string }
variable "app_key_api"  { type = string; sensitive = true }
variable "app_key_admin"{ type = string; sensitive = true }
variable "db_password"  { type = string; sensitive = true }
