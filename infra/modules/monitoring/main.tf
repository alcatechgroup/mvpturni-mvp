# Observabilidade do ambiente (ADR-008), reancorada na VPS pela ADR-021.
#
# O QUE MUDOU EM RELAÇÃO AO CLOUD RUN — e por quê os filtros são o que são:
# antes, `resource.type="cloud_run_revision"` / `"cloud_run_job"` separavam api de
# worker de graça. Numa VPS, TODO log nasce em `resource.type="gce_instance"`, então a
# separação por serviço passa a vir do LOG NAME: o Ops Agent tem um receiver por
# serviço, lendo o arquivo JSON que cada container escreve no volume compartilhado
# (canal `turni_json` do Laravel — config/logging.php). O receiver id vira o log id,
# no formato `turni-<env>-<serviço>`, e é isso que `log_id(...)` casa abaixo.
#
# Consequência boa: o log id já carrega o AMBIENTE, então homolog e prod não se
# misturam mesmo compartilhando o projeto FoodHub com outras aplicações.
#
# As métricas de NEGÓCIO (e-mail crítico, cadastro, SLA de notificação, operações
# financeiras) são as mesmas de antes — elas descrevem o domínio, não a hospedagem.

terraform {
  required_providers {
    time = {
      source = "hashicorp/time"
    }
  }
}

# O Cloud Monitoring leva alguns minutos para reconhecer uma log-based metric recém
# criada, e uma alert policy que a referencie antes disso falha com 404 ("Cannot find
# metric(s) that match type..."). Sem esta espera, o PRIMEIRO apply de um ambiente
# sempre quebra pela metade — descoberto no bring-up do staging (2026-08-01).
resource "time_sleep" "metricas_propagando" {
  create_duration = var.metric_propagation_delay

  depends_on = [
    google_logging_metric.requests,
    google_logging_metric.errors_5xx,
    google_logging_metric.request_duration,
    google_logging_metric.email_failures,
    google_logging_metric.cadastros_completados,
    google_logging_metric.cadastro_completar_falhou,
    google_logging_metric.notificacao_email_sla,
    google_logging_metric.notificacao_email_failures,
    google_logging_metric.pagamento_erros,
    google_logging_metric.pagamento_operacoes,
    google_logging_metric.pagamento_latencia,
    google_logging_metric.pagamento_webhook_latencia,
  ]
}

locals {
  log_api       = "turni-${var.env}-api"
  log_worker    = "turni-${var.env}-worker"
  log_scheduler = "turni-${var.env}-scheduler"

  # Os jobs de fila e o scheduler rodam o MESMO código da api: um evento de negócio
  # pode nascer em qualquer um dos dois. Filtrar só o worker perderia o que o
  # scheduler emitiu.
  log_jobs = "(log_id(\"${local.log_worker}\") OR log_id(\"${local.log_scheduler}\"))"

  gce = "resource.type=\"gce_instance\""
}

# ── Canal de notificação ─────────────────────────────────────────────────────
resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Turni ${var.env} — e-mail de plantão"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

# ── Uptime checks (desligados por padrão — custo do Cloud Monitoring) ────────
resource "google_monitoring_uptime_check_config" "http" {
  for_each = var.enable_uptime_checks ? var.uptime_targets : {}

  project      = var.project_id
  display_name = "Turni ${var.env} — ${each.key}"
  timeout      = "10s"
  period       = "300s"

  http_check {
    path           = each.value.path
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = each.value.host
    }
  }
}

resource "google_monitoring_alert_policy" "uptime_failure" {
  for_each = var.enable_uptime_checks ? var.uptime_targets : {}

  project      = var.project_id
  display_name = "Turni ${var.env} — ${each.key} indisponível"
  combiner     = "OR"

  conditions {
    display_name = "${each.key} não responde"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.labels.check_id=\"${google_monitoring_uptime_check_config.http[each.key].uptime_check_id}\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "600s"
      aggregations {
        alignment_period     = "300s"
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

# ── Saúde da própria VPS ─────────────────────────────────────────────────────
# Novidade da ADR-021: com Cloud Run, capacidade era problema do Google. Agora é
# nosso, e num e2-small o modo de falha real é ficar sem memória ou sem disco —
# que derruba a stack inteira de uma vez, porque tudo mora na mesma máquina.
# Estas métricas vêm do Ops Agent (agent.googleapis.com/*).

resource "google_monitoring_alert_policy" "vps_memory" {
  count = var.enable_vps_alerts ? 1 : 0

  project      = var.project_id
  display_name = "Turni ${var.env} — memória da VPS acima de ${var.memory_threshold_percent}%"
  combiner     = "OR"

  conditions {
    display_name = "Memória usada > ${var.memory_threshold_percent}%"
    condition_threshold {
      filter          = "metric.type=\"agent.googleapis.com/memory/percent_used\" AND resource.type=\"gce_instance\" AND metric.labels.state=\"used\" AND metadata.user_labels.\"env\"=\"${var.env}\" AND metadata.user_labels.\"app\"=\"turni\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.memory_threshold_percent
      duration        = "600s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = "Memória sustentada acima do limite no e2-small. Verifique `docker stats` na VPS; se for regime e não pico, o caminho é subir o machine_type no Terraform, não apertar mais o swap."
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "vps_disk" {
  count = var.enable_vps_alerts ? 1 : 0

  project      = var.project_id
  display_name = "Turni ${var.env} — disco da VPS acima de ${var.disk_threshold_percent}%"
  combiner     = "OR"

  conditions {
    display_name = "Disco usado > ${var.disk_threshold_percent}%"
    condition_threshold {
      filter          = "metric.type=\"agent.googleapis.com/disk/percent_used\" AND resource.type=\"gce_instance\" AND metric.labels.state=\"used\" AND metadata.user_labels.\"env\"=\"${var.env}\" AND metadata.user_labels.\"app\"=\"turni\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.disk_threshold_percent
      duration        = "600s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MAX"
        group_by_fields    = ["metric.labels.device"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.name]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = "Disco cheio derruba o Postgres. Suspeitos usuais: imagens Docker antigas no disco de boot (`docker system prune -af`) e crescimento do banco no disco de dados (redimensionar `data_disk_size_gb`)."
    mime_type = "text/markdown"
  }
}

# ── Métricas RED (ADR-008) ───────────────────────────────────────────────────
resource "google_logging_metric" "requests" {
  project     = var.project_id
  name        = "turni_${var.env}_requests"
  description = "Requisições atendidas pela api/admin (evento request.handled)"
  filter      = "${local.gce} AND log_id(\"${local.log_api}\") AND jsonPayload.event=\"request.handled\""

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
  project     = var.project_id
  name        = "turni_${var.env}_errors_5xx"
  description = "Respostas 5xx da api/admin"
  filter      = "${local.gce} AND log_id(\"${local.log_api}\") AND jsonPayload.status_code>=500"

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
  project     = var.project_id
  name        = "turni_${var.env}_request_duration_ms"
  description = "Latência das requisições atendidas (ms)"
  filter      = "${local.gce} AND log_id(\"${local.log_api}\") AND jsonPayload.event=\"request.handled\""

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

resource "google_monitoring_alert_policy" "error_rate" {
  depends_on = [time_sleep.metricas_propagando]

  project      = var.project_id
  display_name = "Turni ${var.env} — taxa de erro 5xx alta"
  combiner     = "AND"

  conditions {
    display_name = "Taxa de erro > 5%"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_errors_5xx\" AND resource.type=\"gce_instance\""
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

# ── Falha persistente de e-mail crítico (STORY-021 CA-8/CA-9 + ADR-011 §g) ───
# O worker emite ERROR `email.aprovacao.falhou` / `email.recuperacao.falhou` quando o
# job esgota as 3 tentativas (dead letter). O lembrete (warning) é deliberadamente
# excluído: não é fluxo crítico (ADR-011 §g).
resource "google_logging_metric" "email_failures" {
  project     = var.project_id
  name        = "turni_${var.env}_email_failures"
  description = "E-mails críticos que falharam após esgotar as tentativas"
  filter      = "${local.gce} AND ${local.log_jobs} AND (jsonPayload.message=\"email.aprovacao.falhou\" OR jsonPayload.message=\"email.recuperacao.falhou\")"

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
  depends_on = [time_sleep.metricas_propagando]

  project      = var.project_id
  display_name = "Turni ${var.env} — falha de e-mail crítico"
  combiner     = "OR"

  conditions {
    display_name = "E-mail de aprovação/reset falhou após retries"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_email_failures\" AND resource.type=\"gce_instance\""
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

# ── Cadastros completados (STORY-023/024 §observabilidade) ───────────────────
# O api emite INFO `user.cadastro_completed` ao fim do completar cadastro, em
# transação atômica com a geração do AceiteEletronico. Métrica de SUCESSO rotulada
# por papel — alimenta o dashboard "cadastros completados por dia".
resource "google_logging_metric" "cadastros_completados" {
  project     = var.project_id
  name        = "turni_${var.env}_cadastros_completados"
  description = "Cadastros completados, por papel"
  filter      = "${local.gce} AND log_id(\"${local.log_api}\") AND jsonPayload.message=\"user.cadastro_completed\""

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

# Falha do completar cadastro: ERROR `cadastro.template_indisponivel` quando o contrato
# aplicável não tem versão ativa (nenhum aceite é gerado; usuário recebe 503). É o sinal
# acionável — não alertamos anomalia na TAXA de sucesso, que em volume de MVP só gera ruído.
resource "google_logging_metric" "cadastro_completar_falhou" {
  project     = var.project_id
  name        = "turni_${var.env}_cadastro_completar_falhou"
  description = "Tentativas de completar cadastro barradas por template contratual indisponível"
  filter      = "${local.gce} AND log_id(\"${local.log_api}\") AND jsonPayload.message=\"cadastro.template_indisponivel\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "cadastro_completar_falhou" {
  depends_on = [time_sleep.metricas_propagando]

  project      = var.project_id
  display_name = "Turni ${var.env} — completar cadastro falhando (template indisponível)"
  combiner     = "OR"

  conditions {
    display_name = "Completar cadastro falhou (template contratual indisponível)"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_cadastro_completar_falhou\" AND resource.type=\"gce_instance\""
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

# ── SLA de e-mail das notificações (STORY-053 CA-9) ──────────────────────────
# O worker emite INFO `notificacao.email.sent` a cada envio, com `sla_ms` = latência
# ponta-a-ponta (criação da notificação → envio). Distribuição → p50/p95/p99. CA-9: p95 ≤ 60s.
resource "google_logging_metric" "notificacao_email_sla" {
  project     = var.project_id
  name        = "turni_${var.env}_notificacao_email_sla_ms"
  description = "Latência ponta-a-ponta do e-mail de notificação (ms)"
  filter      = "${local.gce} AND ${local.log_jobs} AND jsonPayload.message=\"notificacao.email.sent\""

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

resource "google_monitoring_alert_policy" "notificacao_email_sla" {
  depends_on = [time_sleep.metricas_propagando]

  project      = var.project_id
  display_name = "Turni ${var.env} — SLA de e-mail de notificação acima de 60s (p95)"
  combiner     = "OR"

  conditions {
    display_name = "p95(sla_ms) > 60000ms"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_notificacao_email_sla_ms\" AND resource.type=\"gce_instance\""
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

# Falha definitiva do e-mail de notificação: ERROR `notificacao.email.falhou` ao esgotar
# as 3 tentativas do EnviarEmailDaNotificacaoJob.
resource "google_logging_metric" "notificacao_email_failures" {
  project     = var.project_id
  name        = "turni_${var.env}_notificacao_email_failures"
  description = "E-mails de notificação que falharam definitivamente"
  filter      = "${local.gce} AND ${local.log_jobs} AND jsonPayload.message=\"notificacao.email.falhou\""

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
  depends_on = [time_sleep.metricas_propagando]

  project      = var.project_id
  display_name = "Turni ${var.env} — falha de e-mail de notificação"
  combiner     = "OR"

  conditions {
    display_name = "E-mail de notificação falhou após retries"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_notificacao_email_failures\" AND resource.type=\"gce_instance\""
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
# `pagamento.operacao_concluida|operacao_falhou` nos jobs do worker e
# `pagamento.webhook_processado` na confirmação assíncrona do gateway (fonte de
# verdade — ADR-016 e). Alimentam o SLO de erro ≤ 1% e os p95 de captura e webhook.
# Definição operacional em `docs/operacao/observabilidade-financeira.md`.

resource "google_logging_metric" "pagamento_erros" {
  project     = var.project_id
  name        = "turni_${var.env}_pagamento_erros"
  description = "Operações da ACL de pagamento que falharam"
  filter      = "${local.gce} AND ${local.log_jobs} AND jsonPayload.message=\"pagamento.operacao_falhou\""

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

# Total de operações concluídas — denominador do SLO de erro ≤ 1%.
resource "google_logging_metric" "pagamento_operacoes" {
  project     = var.project_id
  name        = "turni_${var.env}_pagamento_operacoes"
  description = "Operações da ACL de pagamento concluídas com sucesso"
  filter      = "${local.gce} AND ${local.log_jobs} AND jsonPayload.message=\"pagamento.operacao_concluida\""

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

# Latência das operações da ACL — p95 de CAPTURA via label `operacao=captura`.
resource "google_logging_metric" "pagamento_latencia" {
  project     = var.project_id
  name        = "turni_${var.env}_pagamento_latencia_ms"
  description = "Latência das operações da ACL de pagamento (ms)"
  filter      = "${local.gce} AND ${local.log_jobs} AND jsonPayload.message=\"pagamento.operacao_concluida\""

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

# Latência do processamento do webhook do gateway — p95 webhook.
resource "google_logging_metric" "pagamento_webhook_latencia" {
  project     = var.project_id
  name        = "turni_${var.env}_pagamento_webhook_latencia_ms"
  description = "Latência do processamento do webhook do gateway (ms)"
  filter      = "${local.gce} AND ${local.log_jobs} AND jsonPayload.message=\"pagamento.webhook_processado\""

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

# Falha de operação financeira: PDR-010 não tem retry de Pix, então qualquer falha
# já é caso operacional imediato.
resource "google_monitoring_alert_policy" "pagamento_erro" {
  depends_on = [time_sleep.metricas_propagando]

  project      = var.project_id
  display_name = "Turni ${var.env} — falha de operação financeira"
  combiner     = "OR"

  conditions {
    display_name = "pagamento.operacao_falhou registrado"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/turni_${var.env}_pagamento_erros\" AND resource.type=\"gce_instance\""
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
