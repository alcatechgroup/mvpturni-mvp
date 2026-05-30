# Observabilidade mínima (ADR-008):
# - Uptime checks em /health das duas interfaces (+ raiz do webapp)
# - Alert policies para indisponibilidade e erro 5xx
# - Log-based metrics RED (Requests, Errors, Duration)
# - Canal de notificação: e-mail para Alexandro

# ── Canal de notificação ──────────────────────────────────────────────────────
resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "E-mail Alexandro (${var.env})"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

# ── Uptime checks ─────────────────────────────────────────────────────────────
resource "google_monitoring_uptime_check_config" "api_health" {
  project      = var.project_id
  display_name = "Turni API health (${var.env})"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/health"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.api_host
    }
  }
}

resource "google_monitoring_uptime_check_config" "admin_health" {
  project      = var.project_id
  display_name = "Turni Admin health (${var.env})"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/health"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.admin_host
    }
  }
}

resource "google_monitoring_uptime_check_config" "webapp_root" {
  project      = var.project_id
  display_name = "Turni WebApp root (${var.env})"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.webapp_host
    }
  }
}

# ── Alert: indisponibilidade (uptime check falha) ─────────────────────────────
resource "google_monitoring_alert_policy" "uptime_failure" {
  project      = var.project_id
  display_name = "Turni indisponível (${var.env})"
  combiner     = "OR"

  conditions {
    display_name = "API indisponível"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.labels.check_id=\"${google_monitoring_uptime_check_config.api_health.uptime_check_id}\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "120s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.labels.host"]
      }
    }
  }

  conditions {
    display_name = "Admin indisponível"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.labels.check_id=\"${google_monitoring_uptime_check_config.admin_health.uptime_check_id}\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "120s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.labels.host"]
      }
    }
  }

  conditions {
    display_name = "WebApp indisponível"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.labels.check_id=\"${google_monitoring_uptime_check_config.webapp_root.uptime_check_id}\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "120s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.labels.host"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# ── Log-based metrics RED (ADR-008) ──────────────────────────────────────────
resource "google_logging_metric" "requests" {
  project = var.project_id
  name    = "turni_${var.env}_requests"
  filter  = "resource.type=\"cloud_run_revision\" AND jsonPayload.event=\"request.handled\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key         = "service"
      value_type  = "STRING"
      description = "Nome do serviço (api/admin)"
    }
    labels {
      key         = "status_code"
      value_type  = "INT64"
      description = "HTTP status code"
    }
  }

  label_extractors = {
    "service"     = "EXTRACT(jsonPayload.service)"
    "status_code" = "EXTRACT(jsonPayload.status_code)"
  }
}

resource "google_logging_metric" "errors_5xx" {
  project = var.project_id
  name    = "turni_${var.env}_errors_5xx"
  filter  = "resource.type=\"cloud_run_revision\" AND jsonPayload.status_code>=500"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key        = "service"
      value_type = "STRING"
    }
  }

  label_extractors = {
    "service" = "EXTRACT(jsonPayload.service)"
  }
}

resource "google_logging_metric" "request_duration" {
  project = var.project_id
  name    = "turni_${var.env}_request_duration_ms"
  filter  = "resource.type=\"cloud_run_revision\" AND jsonPayload.event=\"request.handled\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    unit        = "ms"
    labels {
      key        = "service"
      value_type = "STRING"
    }
  }

  value_extractor = "EXTRACT(jsonPayload.duration_ms)"

  label_extractors = {
    "service" = "EXTRACT(jsonPayload.service)"
  }

  bucket_options {
    exponential_buckets {
      num_finite_buckets = 20
      growth_factor      = 2
      scale              = 1
    }
  }
}

# ── Alert: taxa de erro 5xx ───────────────────────────────────────────────────
resource "google_monitoring_alert_policy" "error_rate" {
  project      = var.project_id
  display_name = "Turni taxa de erro 5xx alta (${var.env})"
  combiner     = "AND"

  conditions {
    display_name = "Taxa de erro > 5%"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_errors_5xx\" AND resource.type=\"cloud_run_revision\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "300s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]
}

# ── Falha persistente de e-mail crítico (STORY-021 CA-8/CA-9 + ADR-011 §g) ───────
# O worker (Cloud Run Job) emite log ERROR `email.aprovacao.falhou` /
# `email.recuperacao.falhou` quando o job esgota as 3 tentativas (dead letter). Worker
# loga JSON estruturado em stderr (LOG_STDERR_FORMATTER=Monolog JsonFormatter): o nome
# do evento é `jsonPayload.message` e os campos ficam sob `jsonPayload.context.*`. O
# lembrete (warning) é deliberadamente excluído: não é fluxo crítico (ADR-011 §g).
resource "google_logging_metric" "email_failures" {
  project = var.project_id
  name    = "turni_${var.env}_email_failures"
  filter  = "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"turni-worker-job-${var.env}\" AND (jsonPayload.message=\"email.aprovacao.falhou\" OR jsonPayload.message=\"email.recuperacao.falhou\")"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key         = "tipo"
      value_type  = "STRING"
      description = "Tipo do e-mail crítico que falhou (aprovacao_concedida | recuperacao_senha)"
    }
  }

  label_extractors = {
    "tipo" = "EXTRACT(jsonPayload.context.tipo)"
  }
}

resource "google_monitoring_alert_policy" "email_failure" {
  project      = var.project_id
  display_name = "Turni falha de e-mail crítico (${var.env})"
  combiner     = "OR"

  conditions {
    display_name = "E-mail de aprovação/reset falhou após retries"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_email_failures\" AND resource.type=\"cloud_run_job\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}
