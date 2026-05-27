output "app_key_api_secret_id" {
  value = google_secret_manager_secret.app_key_api.secret_id
}

output "app_key_admin_secret_id" {
  value = google_secret_manager_secret.app_key_admin.secret_id
}

output "db_password_secret_id" {
  value = google_secret_manager_secret.db_password.secret_id
}
