variable "project_id"    { type = string }
variable "region"        { type = string; default = "southamerica-east1" }
variable "github_repo"   { type = string }
variable "alert_email"   { type = string }
variable "db_password"   { type = string; sensitive = true }
variable "app_key_api"   { type = string; sensitive = true }
variable "app_key_admin" { type = string; sensitive = true }
variable "api_image"     { type = string; default = "" }
variable "admin_image"   { type = string; default = "" }
