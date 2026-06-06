# Ambiente de homologação do Turni.
# Provisiona: VPC, Cloud SQL, Cloud Run (api + admin), worker (Cloud Run Job — IDR-016),
# Firebase Hosting (webapp), DNS, Secret Manager, Monitoring.
# Recriar do zero: `terraform apply` (ver runbook docs/operacao/runbook-homolog.md).

locals {
  env                = "homolog"
  api_host           = "api.homolog.turni.com.br"
  admin_host         = "admin.homolog.turni.com.br"
  webapp_host        = "app.homolog.turni.com.br"
  landing_host       = "landing.homolog.turni.com.br"
  mail_sender_domain = "mail.homolog.turni.com.br" # remetente Resend (ADR-011 §e)
  mail_from_address  = "no-reply@${local.mail_sender_domain}"
  cloudsql_socket    = "/cloudsql/${module.cloud_sql.connection_name}"
}

# ── APIs GCP necessárias ─────────────────────────────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "dns.googleapis.com",
    "artifactregistry.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "iap.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudscheduler.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ── VPC ──────────────────────────────────────────────────────────────────────
resource "google_compute_network" "main" {
  project                 = var.project_id
  name                    = "turni-${local.env}"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "main" {
  project       = var.project_id
  region        = var.region
  name          = "turni-${local.env}-${var.region}"
  network       = google_compute_network.main.self_link
  ip_cidr_range = "10.1.0.0/24"
}

# Private Service Connection para Cloud SQL sem IP público
resource "google_compute_global_address" "private_ip_range" {
  project       = var.project_id
  name          = "turni-${local.env}-psc-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# ── IAM + WIF ────────────────────────────────────────────────────────────────
module "iam" {
  source      = "../../modules/iam"
  project_id  = var.project_id
  github_repo = var.github_repo
  depends_on  = [google_project_service.apis]
}

# ── Artifact Registry ─────────────────────────────────────────────────────────
module "artifact_registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  region     = var.region
  depends_on = [google_project_service.apis]
}

# ── Segredos ──────────────────────────────────────────────────────────────────
module "secrets" {
  source         = "../../modules/secrets"
  project_id     = var.project_id
  env            = local.env
  app_key_api    = var.app_key_api
  app_key_admin  = var.app_key_admin
  db_password    = var.db_password
  resend_api_key = var.resend_api_key
  depends_on     = [google_project_service.apis]
}

# ── Cloud SQL ─────────────────────────────────────────────────────────────────
module "cloud_sql" {
  source      = "../../modules/cloud-sql"
  project_id  = var.project_id
  region      = var.region
  env         = local.env
  db_password = var.db_password
  vpc_network = google_compute_network.main.self_link
  depends_on  = [google_service_networking_connection.private_vpc_connection]
}

# ── Cloud Run: API (público) ──────────────────────────────────────────────────
module "cloud_run_api" {
  source                   = "../../modules/cloud-run"
  project_id               = var.project_id
  region                   = var.region
  app                      = "api"
  env                      = local.env
  image                    = var.api_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  ingress                  = "INGRESS_TRAFFIC_ALL"
  allow_unauthenticated    = true
  # Direct VPC egress: Cloud SQL é IP privado; sem isto o socket dá timeout (STORY-016).
  vpc_network    = google_compute_network.main.name
  vpc_subnetwork = google_compute_subnetwork.main.name

  env_vars = {
    APP_ENV          = "production"
    APP_DEBUG        = "false"
    APP_URL          = "https://${local.webapp_host}"
    LOG_CHANNEL      = "stderr"
    DB_CONNECTION    = "pgsql"
    DB_SOCKET        = local.cloudsql_socket
    DB_DATABASE      = "turni"
    DB_USERNAME      = "turni"
    QUEUE_CONNECTION = "database"
    SESSION_DRIVER   = "database"
    # __session é obrigatório atrás do Firebase Hosting: o Hosting só encaminha ao Cloud Run
    # o cookie chamado `__session` (descarta os demais). Sem isso, a sessão não chega ao
    # backend e toda request autenticada cai em 401 após o login. Ver IDR-019.
    SESSION_COOKIE = "__session"
    # E-mail transacional (ADR-011 §c): provedor Resend em homolog; chave via Secret
    # Manager (secret_env_vars). Remetente no subdomínio dedicado mail.homolog.
    MAIL_MAILER       = "resend"
    MAIL_FROM_ADDRESS = local.mail_from_address
    MAIL_FROM_NAME    = "Turni"
    # Sanctum SPA: o WebApp é servido em app.homolog e chama /api no MESMO domínio
    # (Firebase rewrite → este Cloud Run). Marca o domínio como stateful p/ usar a
    # sessão por cookie. BACKOFFICE_URL alimenta o banner "Ir para o Backoffice".
    SANCTUM_STATEFUL_DOMAINS = local.webapp_host
    BACKOFFICE_URL           = "https://turni-admin-homolog-dnj2tcr2xa-rj.a.run.app"
    # Gateway de pagamento = fake genérico (PDR-017 / ADR-016 d): driver `mock` é o
    # único do MVP; base_url aponta para o Cloud Run do fake (ver bloco no fim do arquivo).
    PAGARME_DRIVER   = "mock"
    PAGARME_BASE_URL = google_cloud_run_v2_service.pagarme_mock.uri
  }

  secret_env_vars = {
    APP_KEY                = { secret = module.secrets.app_key_api_secret_id, version = "latest" }
    DB_PASSWORD            = { secret = module.secrets.db_password_secret_id, version = "latest" }
    RESEND_API_KEY         = { secret = module.secrets.resend_api_key_secret_id, version = "latest" }
    PAGARME_SECRET_KEY     = { secret = google_secret_manager_secret.pagarme_secret_key.secret_id, version = "latest" }
    PAGARME_WEBHOOK_SECRET = { secret = google_secret_manager_secret.pagarme_webhook_secret.secret_id, version = "latest" }
    PIX_FALHA_CHAVE_KEY    = { secret = google_secret_manager_secret.pix_falha_chave_key.secret_id, version = "latest" } # IDR-028
  }

  depends_on = [module.cloud_sql, module.secrets]
}

# ── Cloud Run: Admin (homolog: público para E2E; prod: interno + IAP — IDR-003) ─
module "cloud_run_admin" {
  source                   = "../../modules/cloud-run"
  project_id               = var.project_id
  region                   = var.region
  app                      = "admin"
  env                      = local.env
  image                    = var.admin_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  ingress                  = "INGRESS_TRAFFIC_ALL"
  allow_unauthenticated    = true
  # Direct VPC egress: o admin também conecta ao Cloud SQL de IP privado via socket
  # (DB_SOCKET); sem isto o socket dá timeout (IDR-007). Estava aplicado ao vivo mas
  # ausente do módulo — reconciliado durante a STORY-034 para zerar o drift (CA-4).
  vpc_network    = google_compute_network.main.name
  vpc_subnetwork = google_compute_subnetwork.main.name

  env_vars = {
    APP_ENV   = "production"
    APP_DEBUG = "false"
    # APP_URL aponta para a WebApp: o e-mail de aprovação (admin ApprovalService) monta o
    # CTA "Acessar o Turni" com config('app.webapp_url', config('app.url')); sem APP_URL o
    # default do Laravel (http://localhost) ia no e-mail. O backoffice é Livewire (URLs
    # relativas), então não depende de uma APP_URL própria.
    APP_URL        = "https://${local.webapp_host}"
    LOG_CHANNEL    = "stderr"
    DB_CONNECTION  = "pgsql"
    DB_SOCKET      = local.cloudsql_socket
    DB_DATABASE    = "turni"
    DB_USERNAME    = "turni"
    SESSION_DRIVER = "cookie"
  }

  secret_env_vars = {
    APP_KEY             = { secret = module.secrets.app_key_admin_secret_id, version = "latest" }
    PIX_FALHA_CHAVE_KEY = { secret = google_secret_manager_secret.pix_falha_chave_key.secret_id, version = "latest" } # IDR-028 — lê a chave Pix do snapshot
    DB_PASSWORD         = { secret = module.secrets.db_password_secret_id, version = "latest" }
  }

  depends_on = [module.cloud_sql, module.secrets]
}

# ── Worker (Cloud Run Job + Cloud Scheduler — IDR-016) ────────────────────────
# Substitui o GCE worker-vm (que nunca funcionou em homolog: 5 gaps de infra, ver
# IDR-016). Cloud Scheduler dispara o Job a cada 1 min; o Job roda
# `queue:work --stop-when-empty` e sai quando a fila esvazia. Mesma fiação do
# cloud_run_api (Direct VPC egress + Cloud SQL socket + secret_env_vars).
# Reversão: trocar este bloco por `module "worker"` (worker-vm, mantido desabilitado).

# Ambiente compartilhado worker + scheduler (STORY-073): os dois Jobs rodam a MESMA
# imagem da api e precisam de paridade total — os comandos agendados enviam e-mail
# (Resend), enfileiram jobs e chamam a ACL de pagamento, igual ao worker.
locals {
  job_env_vars = {
    APP_ENV           = "production"
    APP_DEBUG         = "false"
    APP_URL           = "https://${local.webapp_host}"
    LOG_CHANNEL       = "stderr"
    DB_CONNECTION     = "pgsql"
    DB_SOCKET         = local.cloudsql_socket
    DB_DATABASE       = "turni"
    DB_USERNAME       = "turni"
    QUEUE_CONNECTION  = "database"
    MAIL_MAILER       = "resend"
    MAIL_FROM_ADDRESS = local.mail_from_address
    MAIL_FROM_NAME    = "Turni"
    # Log JSON estruturado em stderr → Cloud Logging parseia como jsonPayload, o que
    # alimenta a métrica/alerta de falha de e-mail crítico (STORY-021 CA-8/CA-9) e as
    # log-based metrics. Sem rebuild: o canal `stderr` lê o formatter desta env.
    LOG_STDERR_FORMATTER = "Monolog\\Formatter\\JsonFormatter"
    # Gateway de pagamento = fake genérico (PDR-017 / ADR-016 d). É o worker quem executa
    # as chamadas da ACL (jobs PreAutorizar/Capturar/etc — ADR-002), daí a paridade.
    PAGARME_DRIVER   = "mock"
    PAGARME_BASE_URL = google_cloud_run_v2_service.pagarme_mock.uri
  }

  job_secret_env_vars = {
    APP_KEY                = { secret = module.secrets.app_key_api_secret_id, version = "latest" }
    DB_PASSWORD            = { secret = module.secrets.db_password_secret_id, version = "latest" }
    RESEND_API_KEY         = { secret = module.secrets.resend_api_key_secret_id, version = "latest" }
    PAGARME_SECRET_KEY     = { secret = google_secret_manager_secret.pagarme_secret_key.secret_id, version = "latest" }
    PAGARME_WEBHOOK_SECRET = { secret = google_secret_manager_secret.pagarme_webhook_secret.secret_id, version = "latest" }
    PIX_FALHA_CHAVE_KEY    = { secret = google_secret_manager_secret.pix_falha_chave_key.secret_id, version = "latest" } # IDR-028
  }
}

module "worker_job" {
  source                   = "../../modules/worker-job"
  project_id               = var.project_id
  region                   = var.region
  env                      = local.env
  image                    = var.api_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  vpc_network              = google_compute_network.main.name
  vpc_subnetwork           = google_compute_subnetwork.main.name

  # Paridade de ambiente com o cloud_run_api (o worker roda o mesmo código).
  env_vars        = local.job_env_vars
  secret_env_vars = local.job_secret_env_vars

  depends_on = [module.cloud_sql, module.secrets]
}

# ── Scheduler do Laravel (Cloud Run Job + Cloud Scheduler — STORY-073) ────────
# Quita a F-NB-1 do EPIC-002: nada invocava `php artisan schedule:run` no ambiente
# implantado, então os `Schedule::command(...)` de routes/console.php (auto-retirada
# pós-edição PDR-009, lembretes de cadastro, sweeper de e-mail, detecção de no-show)
# nunca disparavam. Mesmo padrão do worker (IDR-016), Job SEPARADO de propósito:
# kill-switch independente — pausar a fila não desliga o cron e vice-versa.
# `schedule:run` avalia o que está "due" no minuto corrente e sai; o tick de 1 min
# vem do everyMinute() declarado no código (STORY-052). withoutOverlapping (mutex em
# cache=database) protege contra sobreposição se uma execução passar de 60s.
module "scheduler_job" {
  source                   = "../../modules/worker-job"
  project_id               = var.project_id
  region                   = var.region
  env                      = local.env
  name                     = "scheduler"
  sa_account_short         = "schd"
  command                  = ["php", "artisan", "schedule:run"]
  image                    = var.api_image
  service_account_email    = module.iam.apps_service_account_email
  cloudsql_connection_name = module.cloud_sql.connection_name
  vpc_network              = google_compute_network.main.name
  vpc_subnetwork           = google_compute_subnetwork.main.name

  # Mesma paridade do worker: os comandos agendados rodam o mesmo código da api.
  env_vars        = local.job_env_vars
  secret_env_vars = local.job_secret_env_vars

  depends_on = [module.cloud_sql, module.secrets]
}

# ── Fake de pagamento (PDR-017 / ADR-016 d) — SÓ homolog, nunca prod ─────────
# O fake genérico (pagarme-mock) é o gateway de pagamento EFETIVO do MVP em homolog:
# processa pré-auth/captura/Pix no contrato Pagar.me e devolve o webhook assinado ao
# api. Não usa Cloud SQL nem VPC (por isso resource direto, não o módulo cloud-run).
# Secrets próprios (Bearer + HMAC) compartilhados com api/worker via Secret Manager
# (ADR-004); o SA das apps já tem secretAccessor no projeto (módulo iam). Este bloco
# inteiro SAI quando o PSP real entrar (épico da próxima wave).

resource "google_secret_manager_secret" "pagarme_secret_key" {
  project   = var.project_id
  secret_id = "turni-${local.env}-pagarme-secret-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "pagarme_secret_key" {
  secret      = google_secret_manager_secret.pagarme_secret_key.id
  secret_data = var.pagarme_secret_key
}

resource "google_secret_manager_secret" "pagarme_webhook_secret" {
  project   = var.project_id
  secret_id = "turni-${local.env}-pagarme-webhook-secret"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "pagarme_webhook_secret" {
  secret      = google_secret_manager_secret.pagarme_webhook_secret.id
  secret_data = var.pagarme_webhook_secret
}

# STORY-065 (IDR-028) — segredo DEDICADO da chave Pix do snapshot de pix_falhas,
# COMPARTILHADO entre api/worker (escreve) e admin (lê para o tratamento manual).
# Distinto das APP_KEYs dos dois apps (espírito da ADR-009 5A).
resource "google_secret_manager_secret" "pix_falha_chave_key" {
  project   = var.project_id
  secret_id = "turni-${local.env}-pix-falha-chave-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "pix_falha_chave_key" {
  secret      = google_secret_manager_secret.pix_falha_chave_key.id
  secret_data = var.pix_falha_chave_key
}

resource "google_cloud_run_v2_service" "pagarme_mock" {
  project  = var.project_id
  name     = "turni-pagarme-mock-${local.env}"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL" # público; o Bearer (PAGARME_SECRET_KEY) barra POST anônimo

  # Fake descartável de homolog (sai com o PSP real na próxima wave) — sem proteção de delete.
  deletion_protection = false

  template {
    service_account = module.iam.apps_service_account_email

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      image = var.pagarme_mock_image

      ports {
        container_port = 8080
      }

      env {
        # URL direta do Cloud Run api (hardcoded como o BACKOFFICE_URL acima: referenciar
        # module.cloud_run_api aqui criaria ciclo, pois o api referencia a uri deste serviço).
        name  = "PAGARME_WEBHOOK_TARGET"
        value = "https://turni-api-homolog-dnj2tcr2xa-rj.a.run.app/api/webhooks/pagarme"
      }
      env {
        # STORY-065 (CA-5) — cenário do Pix: `sucesso` | `falha` (webhook transfer.failed
        # determinístico p/ exercitar a fila "Pix com falha" do admin em homolog).
        name  = "PAGARME_MOCK_PIX_RESULTADO"
        value = var.pagarme_mock_pix_resultado
      }
      env {
        # STORY-065 (CA-7 / PDR-017) — SLA do webhook do Pix (~30s simula a promessa
        # "Pix em ≤ 15 min"; a resposta HTTP não espera). Exige CPU always-allocated.
        name  = "PAGARME_MOCK_PIX_SLA_SEGUNDOS"
        value = tostring(var.pagarme_mock_pix_sla_segundos)
      }
      env {
        # O sleep do SLA segura um worker do php -S; 8 workers mantêm o fake atendendo.
        name  = "PHP_CLI_SERVER_WORKERS"
        value = "8"
      }
      env {
        name = "PAGARME_SECRET_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.pagarme_secret_key.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "PAGARME_WEBHOOK_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.pagarme_webhook_secret.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi" # < 512Mi não é aceito pelo Cloud Run v2 com CPU always-allocated
        }
        # STORY-065 — o webhook do Pix é emitido APÓS a resposta (SLA configurável); com
        # CPU throttled o processo congela ao fechar a conexão e o webhook nunca sai.
        cpu_idle = false
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 10
        period_seconds        = 30
        timeout_seconds       = 5
        failure_threshold     = 3
      }
    }
  }

  lifecycle {
    ignore_changes = [
      # O pipeline gerencia a imagem; o Terraform não sobrescreve deploys do CI
      template[0].containers[0].image,
    ]
  }

  depends_on = [
    google_secret_manager_secret_version.pagarme_secret_key,
    google_secret_manager_secret_version.pagarme_webhook_secret,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "pagarme_mock_public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.pagarme_mock.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ── Firebase Hosting (WebApp Flutter + landing institucional) ────────────────
# Site principal: WebApp. Site adicional: landing (ADR-012 — site único por ambiente
# que serve "Em breve" no apex, landing AS IS no path secreto, robots.txt e 404).
module "firebase" {
  source        = "../../modules/firebase"
  project_id    = var.project_id
  env           = local.env
  custom_domain = local.webapp_host
  additional_sites = {
    landing = {
      site_id       = "turni-landing-${local.env}" # turni-landing-homolog
      custom_domain = local.landing_host           # landing.homolog.turni.com.br
    }
  }
  depends_on = [google_project_service.apis]
}

# ── Agendamento liga/desliga do Cloud SQL (economia de custo) ─────────────────
# Desliga: seg–sex 22h BRT; sáb+dom ficam desligados.
# Liga: seg–sex 06h BRT.
module "sql_scheduler" {
  source        = "../../modules/sql-scheduler"
  project_id    = var.project_id
  region        = var.region
  env           = local.env
  instance_name = module.cloud_sql.instance_name
  depends_on    = [google_project_service.apis, module.cloud_sql]
}

# ── DNS (Cloud DNS) ──────────────────────────────────────────────────────────
# Fase 1 (feita): zona criada, NS configurados no registro.br.
# Fase 2 (esta): CNAME webapp → Firebase (app.homolog.turni.com.br).
# API: Cloud Run domain mapping não é suportado em southamerica-east1.
#      Em homolog: acesso via URL direta do Cloud Run.
#      Em prod: provisionar HTTPS LB + Serverless NEG.
module "dns" {
  source               = "../../modules/dns"
  project_id           = var.project_id
  create_zone          = true
  dns_zone_name        = "turni-com-br"
  webapp_subdomain     = local.webapp_host
  webapp_cname_target  = module.firebase.cname_target
  landing_subdomain    = local.landing_host
  landing_cname_target = module.firebase.additional_cname_targets["landing"]

  # Domínio remetente de e-mail (Resend — ADR-011 §e / STORY-021). Região sa-east-1
  # (default do módulo). DKIM é a chave pública gerada pelo Resend (dado público de DNS).
  mail_sender_domain = local.mail_sender_domain
  mail_dkim_value    = var.mail_dkim_value

  depends_on = [google_project_service.apis, module.firebase]
}

# ── Monitoramento (ADR-008) ───────────────────────────────────────────────────
module "monitoring" {
  source      = "../../modules/monitoring"
  project_id  = var.project_id
  env         = local.env
  alert_email = var.alert_email
  api_host    = local.api_host
  admin_host  = local.admin_host
  webapp_host = local.webapp_host
  depends_on  = [google_project_service.apis]
}
