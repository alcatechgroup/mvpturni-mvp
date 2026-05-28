output "sql_stop_job_name" {
  value = google_cloud_scheduler_job.sql_stop.name
}

output "sql_start_job_name" {
  value = google_cloud_scheduler_job.sql_start.name
}

output "worker_stop_job_name" {
  value = google_cloud_scheduler_job.worker_stop.name
}

output "worker_start_job_name" {
  value = google_cloud_scheduler_job.worker_start.name
}

output "service_account_email" {
  value = google_service_account.sql_scheduler.email
}
