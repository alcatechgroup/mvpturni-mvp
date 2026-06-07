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

# ── Cadastros completados (STORY-023/024 §observabilidade) ────────────────────
# O api (Cloud Run) emite INFO `user.cadastro_completed` ao fim do completar cadastro
# (profissional ou contratante), em transação atômica com a geração do AceiteEletronico.
# Log Monolog JsonFormatter: o nome do evento é `jsonPayload.message` e os campos ficam
# sob `jsonPayload.context.*` (mesma forma do `email_failures` do worker). Métrica de
# SUCESSO rotulada por papel — alimenta o dashboard "cadastros completados por dia".
resource "google_logging_metric" "cadastros_completados" {
  project = var.project_id
  name    = "turni_${var.env}_cadastros_completados"
  filter  = "resource.type=\"cloud_run_revision\" AND jsonPayload.message=\"user.cadastro_completed\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key         = "role"
      value_type  = "STRING"
      description = "Papel de quem completou o cadastro (profissional | contratante)"
    }
  }

  label_extractors = {
    "role" = "EXTRACT(jsonPayload.context.role)"
  }
}

# Falha do completar cadastro: o api loga ERROR `cadastro.template_indisponivel` quando
# o contrato aplicável não tem versão ativa (nenhum aceite é gerado; usuário recebe 503).
# É o sinal acionável de "completar cadastro está falhando" — vale alerta imediato.
# (Decisão: NÃO alertamos anomalia na TAXA de sucesso — em volume de MVP gera ruído; o
# sinal de falha concreto é este. A métrica de sucesso acima fica para o dashboard.)
resource "google_logging_metric" "cadastro_completar_falhou" {
  project = var.project_id
  name    = "turni_${var.env}_cadastro_completar_falhou"
  filter  = "resource.type=\"cloud_run_revision\" AND jsonPayload.message=\"cadastro.template_indisponivel\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "cadastro_completar_falhou" {
  project      = var.project_id
  display_name = "Turni completar cadastro falhando — template indisponível (${var.env})"
  combiner     = "OR"

  conditions {
    display_name = "Completar cadastro falhou (template contratual indisponível)"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_cadastro_completar_falhou\" AND resource.type=\"cloud_run_revision\""
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

# ── SLA de e-mail das notificações (STORY-053 CA-9) ───────────────────────────
# O worker (queue:work) emite INFO `notificacao.email.sent` ao enviar cada e-mail de
# notificação, com `sla_ms` = latência ponta-a-ponta (criação da notificação → envio).
# Log Monolog JsonFormatter: evento em `jsonPayload.message`, campos sob
# `jsonPayload.context.*` (mesma forma do `email_failures`). Métrica de DISTRIBUIÇÃO →
# permite p50/p95/p99 no dashboard e no alerta. CA-9: p95 ≤ 60s.
resource "google_logging_metric" "notificacao_email_sla" {
  project = var.project_id
  name    = "turni_${var.env}_notificacao_email_sla_ms"
  filter  = "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"turni-worker-job-${var.env}\" AND jsonPayload.message=\"notificacao.email.sent\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    unit        = "ms"
    labels {
      key         = "tipo"
      value_type  = "STRING"
      description = "Tipo da notificação (candidatura_recebida | vaga_editada_material | vaga_cancelada | ...)"
    }
  }

  value_extractor = "EXTRACT(jsonPayload.context.sla_ms)"

  label_extractors = {
    "tipo" = "EXTRACT(jsonPayload.context.tipo)"
  }

  bucket_options {
    exponential_buckets {
      num_finite_buckets = 20
      growth_factor      = 2
      scale              = 1
    }
  }
}

# Alerta: p95 do SLA acima de 60s (CA-9). Janela de 5 min para evitar ruído de spikes.
resource "google_monitoring_alert_policy" "notificacao_email_sla" {
  project      = var.project_id
  display_name = "Turni SLA de e-mail de notificação > 60s p95 (${var.env})"
  combiner     = "OR"

  conditions {
    display_name = "p95(sla_ms) > 60000ms"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_notificacao_email_sla_ms\" AND resource.type=\"cloud_run_job\""
      comparison      = "COMPARISON_GT"
      threshold_value = 60000
      duration        = "300s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_PERCENTILE_95"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "1800s"
  }
}

# Falha definitiva de e-mail de notificação: o worker loga ERROR `notificacao.email.falhou`
# ao esgotar as 3 tentativas do EnviarEmailDaNotificacaoJob. Sinal acionável de "notificações
# não estão saindo" — alerta imediato (mesmo padrão do `email_failure` crítico).
resource "google_logging_metric" "notificacao_email_failures" {
  project = var.project_id
  name    = "turni_${var.env}_notificacao_email_failures"
  filter  = "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"turni-worker-job-${var.env}\" AND jsonPayload.message=\"notificacao.email.falhou\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key         = "tipo"
      value_type  = "STRING"
      description = "Tipo da notificação cujo e-mail falhou definitivamente"
    }
  }

  label_extractors = {
    "tipo" = "EXTRACT(jsonPayload.context.tipo)"
  }
}

resource "google_monitoring_alert_policy" "notificacao_email_failure" {
  project      = var.project_id
  display_name = "Turni falha de e-mail de notificação (${var.env})"
  combiner     = "OR"

  conditions {
    display_name = "E-mail de notificação falhou após retries"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_notificacao_email_failures\" AND resource.type=\"cloud_run_job\""
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

# ── Operações financeiras (EPIC-003 / ADR-016 g / STORY-068 F-NB-1) ──────────
# A ACL de pagamento emite uma linha JSON por operação (PagamentoEvents — ADR-008):
# `pagamento.operacao_concluida|operacao_falhou` nos jobs do worker (pré-auth na
# aprovação, captura+Pix no TurnoFinalizado, liberação no cancelamento/no-show) e
# `pagamento.webhook_processado` na confirmação assíncrona do gateway (fonte de
# verdade — ADR-016 e). Estas métricas alimentam o SLO de erro ≤ 1% e os p95 de
# captura e de webhook prometidos pela ADR-016. Definição operacional em
# `docs/operacao/observabilidade-financeira.md`.

# Erros de operação financeira (counter). SLO ≤ 1% sobre o total de operações; o
# alerta abaixo dispara em QUALQUER falha (volume atual é baixo — 1 falha já é
# acionável e o PDR-010 não tem retry de Pix).
resource "google_logging_metric" "pagamento_erros" {
  project = var.project_id
  name    = "turni_${var.env}_pagamento_erros"
  filter  = "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"turni-worker-job-${var.env}\" AND jsonPayload.message=\"pagamento.operacao_falhou\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key         = "operacao"
      value_type  = "STRING"
      description = "Operação da ACL (pre_autorizacao | captura | pix | liberacao)"
    }
    labels {
      key         = "recuperavel"
      value_type  = "STRING"
      description = "true = GatewayIndisponivel (job retenta); false = falha fatal de negócio"
    }
  }

  label_extractors = {
    "operacao"    = "EXTRACT(jsonPayload.context.operacao)"
    "recuperavel" = "EXTRACT(jsonPayload.context.recuperavel)"
  }
}

# Total de operações concluídas (counter) — denominador do SLO de erro ≤ 1%.
resource "google_logging_metric" "pagamento_operacoes" {
  project = var.project_id
  name    = "turni_${var.env}_pagamento_operacoes"
  filter  = "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"turni-worker-job-${var.env}\" AND jsonPayload.message=\"pagamento.operacao_concluida\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key         = "operacao"
      value_type  = "STRING"
      description = "Operação da ACL (pre_autorizacao | captura | pix | liberacao)"
    }
  }

  label_extractors = {
    "operacao" = "EXTRACT(jsonPayload.context.operacao)"
  }
}

# Latência das operações da ACL (distribution, ms) — p95 de CAPTURA via label
# `operacao=captura` (pix/liberação/pré-auth saem de graça pela mesma métrica).
resource "google_logging_metric" "pagamento_latencia" {
  project = var.project_id
  name    = "turni_${var.env}_pagamento_latencia_ms"
  filter  = "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"turni-worker-job-${var.env}\" AND jsonPayload.message=\"pagamento.operacao_concluida\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    unit        = "ms"
    labels {
      key         = "operacao"
      value_type  = "STRING"
      description = "Operação da ACL (pre_autorizacao | captura | pix | liberacao)"
    }
  }

  value_extractor = "EXTRACT(jsonPayload.context.latencia_ms)"

  label_extractors = {
    "operacao" = "EXTRACT(jsonPayload.context.operacao)"
  }

  bucket_options {
    exponential_buckets {
      num_finite_buckets = 20
      growth_factor      = 2
      scale              = 1
    }
  }
}

# Latência do processamento do webhook do gateway (distribution, ms) — p95 webhook.
resource "google_logging_metric" "pagamento_webhook_latencia" {
  project = var.project_id
  name    = "turni_${var.env}_pagamento_webhook_latencia_ms"
  filter  = "resource.type=\"cloud_run_job\" AND resource.labels.job_name=\"turni-worker-job-${var.env}\" AND jsonPayload.message=\"pagamento.webhook_processado\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    unit        = "ms"
    labels {
      key         = "evento_dominio"
      value_type  = "STRING"
      description = "Evento de domínio emitido (PreAutorizacaoCriada | CapturaConfirmada | PixEnviado | PixFalhou | PreAutorizacaoLiberada)"
    }
  }

  value_extractor = "EXTRACT(jsonPayload.context.latencia_ms)"

  label_extractors = {
    "evento_dominio" = "EXTRACT(jsonPayload.context.evento_dominio)"
  }

  bucket_options {
    exponential_buckets {
      num_finite_buckets = 20
      growth_factor      = 2
      scale              = 1
    }
  }
}

# Alerta: falha de operação financeira (PDR-010 — Pix sem retry; falha é caso
# operacional imediato, espelha o padrão do notificacao_email_failure).
resource "google_monitoring_alert_policy" "pagamento_erro" {
  project      = var.project_id
  display_name = "Turni falha de operação financeira (${var.env})"
  combiner     = "OR"

  conditions {
    display_name = "pagamento.operacao_falhou registrado"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_pagamento_erros\" AND resource.type=\"cloud_run_job\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"
      trigger {
        count = 1
      }
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
