output "job_name" {
  description = "Nome do Cloud Run Job do worker (usado pelo release.yml e runbook)."
  value       = google_cloud_run_v2_job.worker.name
}

output "scheduler_job_name" {
  description = "Nome do Cloud Scheduler que dispara o worker (kill-switch: scheduler jobs pause)."
  value       = google_cloud_scheduler_job.worker_tick.name
}

output "scheduler_service_account_email" {
  description = "E-mail da SA dedicada do Scheduler (só roles/run.invoker no Job)."
  value       = google_service_account.worker_scheduler.email
}
