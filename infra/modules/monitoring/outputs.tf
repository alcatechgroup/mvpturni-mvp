output "notification_channel" {
  description = "Resource name do canal de notificação por e-mail"
  value       = google_monitoring_notification_channel.email.name
}
