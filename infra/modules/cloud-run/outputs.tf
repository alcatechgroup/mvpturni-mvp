output "service_url" {
  description = "URL do serviço Cloud Run"
  value       = google_cloud_run_v2_service.service.uri
}

output "service_name" {
  value = google_cloud_run_v2_service.service.name
}
