output "connection_name" {
  description = "Cloud SQL connection name (project:region:instance) — usado pelo Cloud Run e worker"
  value       = google_sql_database_instance.main.connection_name
}

output "instance_name" {
  value = google_sql_database_instance.main.name
}

output "private_ip" {
  value = google_sql_database_instance.main.private_ip_address
}
