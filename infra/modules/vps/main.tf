# VPS de um ambiente do Turni (ADR-021): uma única instância Compute Engine roda
# a stack inteira em containers — Caddy, api, admin, worker, scheduler, WebApp,
# landing e o Postgres.
#
# Peças e o porquê de cada uma:
#   • IP externo ESTÁTICO — o registro A na Cloudflare aponta para ele; efêmero
#     mudaria a cada stop/start e quebraria o DNS. O IP não é superfície de ataque:
#     o firewall do módulo network só aceita 80/443 da Cloudflare e 22 do IAP.
#   • DISCO DE DADOS separado do boot — o Postgres e o storage do Laravel vivem nele.
#     Recriar/redimensionar a VM (`terraform taint`) não toca no dado, e o disco tem
#     `prevent_destroy`.
#   • BUCKET DE CONFIG — o Terraform publica nele o runtime da VPS (compose, Caddyfile,
#     scripts de infra/vps/). O boot e cada deploy sincronizam. Assim, mudar o Caddyfile
#     é um `terraform apply` + `deploy.sh --sync`, sem recriar a instância.
#   • BUCKET DE BACKUPS — destino dos dumps do Postgres (cron na VM), com lifecycle
#     de retenção.
#   • SA DEDICADA por ambiente, com o mínimo: ler segredos, ler imagens, escrever
#     logs/métricas, ler o bucket de config e escrever no de backup.

locals {
  data_device_name = "turni-data"

  # Buckets são namespace GLOBAL: o prefixo `turni-<env>` identifica a aplicação na
  # listagem do projeto (que hospeda outras apps da FoodHub) e o sufixo com o
  # project_id garante unicidade sem depender de sorte.
  config_bucket_name  = "${var.name_prefix}-config-${var.project_id}"
  backups_bucket_name = "${var.name_prefix}-backups-${var.project_id}"

  # Arquivos de runtime versionados no repo que são publicados no bucket de config.
  runtime_files = fileset(var.runtime_source_dir, "**")

  startup_script = templatefile("${path.module}/templates/startup.sh.tftpl", {
    env               = var.env
    region            = var.region
    data_device_name  = local.data_device_name
    data_mount_point  = var.data_mount_point
    config_bucket     = google_storage_bucket.config.name
    app_dir           = var.app_dir
    install_ops_agent = var.install_ops_agent
  })
}

# ── Service account da VPS ───────────────────────────────────────────────────
resource "google_service_account" "vm" {
  project      = var.project_id
  account_id   = "${var.name_prefix}-vm"
  display_name = "Turni ${var.env} — runtime da VPS"
  description  = "Identidade da instância que roda a stack do Turni em ${var.env}"
}

resource "google_project_iam_member" "vm_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_project_iam_member" "vm_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

# Necessário para o Ops Agent publicar o self-report de saúde do próprio agente.
resource "google_project_iam_member" "vm_metadata_writer" {
  project = var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

# Puxar as imagens do Artifact Registry no `docker compose pull`.
resource "google_project_iam_member" "vm_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

# Acesso aos segredos do PRÓPRIO ambiente (concedido secret a secret pelo env, não
# no nível do projeto — a VPS de homolog não enxerga segredo de prod).
resource "google_secret_manager_secret_iam_member" "vm_secret_accessor" {
  for_each = toset(var.accessible_secret_ids)

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vm.email}"
}

# Quem faz deploy (a SA do CI) precisa PODER USAR a identidade da VPS para abrir a
# sessão SSH. Concedido aqui, no ambiente, e não no projeto: o CI não ganha poder
# sobre service accounts de outras aplicações da FoodHub.
resource "google_service_account_iam_member" "deployer_sa_user" {
  for_each = toset(var.deployer_members)

  service_account_id = google_service_account.vm.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}

# ── Endereço externo estático ────────────────────────────────────────────────
resource "google_compute_address" "this" {
  project      = var.project_id
  region       = var.region
  name         = "${var.name_prefix}-ip"
  address_type = "EXTERNAL"
  description  = "IP público da VPS do Turni ${var.env} (alvo dos registros A na Cloudflare)"
  labels       = var.labels

  # PRECISA casar com o network_tier do access_config da instância, senão o GCE
  # recusa a associação ("has a different network tier"). Sem isto, o endereço nasce
  # PREMIUM (default) e a instância STANDARD nunca sobe.
  network_tier = var.network_tier
}

# ── Disco de dados (Postgres + storage das apps) ─────────────────────────────
resource "google_compute_disk" "data" {
  project = var.project_id
  zone    = var.zone
  name    = "${var.name_prefix}-data"
  type    = var.data_disk_type
  size    = var.data_disk_size_gb
  labels  = merge(var.labels, { component = "data" })

  lifecycle {
    # O dado do ambiente vive aqui. Trocar tipo/tamanho para baixo, ou recriar a VM,
    # não pode levar o banco junto — destruir exige remover este bloco de propósito.
    prevent_destroy = true
  }
}

# ── Buckets: configuração de runtime e backups ───────────────────────────────
resource "google_storage_bucket" "config" {
  project                     = var.project_id
  name                        = local.config_bucket_name
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true # só conteúdo derivado do repo; recriável
  labels                      = merge(var.labels, { component = "config" })

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "backups" {
  project                     = var.project_id
  name                        = local.backups_bucket_name
  location                    = var.region
  storage_class               = "NEARLINE"
  uniform_bucket_level_access = true
  labels                      = merge(var.labels, { component = "backups" })

  lifecycle_rule {
    condition {
      age = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket_iam_member" "vm_config_reader" {
  bucket = google_storage_bucket.config.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_storage_bucket_iam_member" "vm_backups_writer" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.vm.email}"
}

# Publica o runtime da VPS (infra/vps/**) no bucket. `detect_md5hash` faz o Terraform
# ver a mudança de conteúdo, então editar o Caddyfile no repo vira drift detectável.
resource "google_storage_bucket_object" "runtime" {
  for_each = local.runtime_files

  bucket = google_storage_bucket.config.name
  name   = "runtime/${each.value}"
  source = "${var.runtime_source_dir}/${each.value}"

  # Sem isso o Terraform só compara o nome e nunca republica um arquivo editado.
  # (`detect_md5hash` era o campo antigo, hoje deprecado.)
  source_md5hash = filemd5("${var.runtime_source_dir}/${each.value}")
}

# Arquivo de ambiente NÃO-secreto, gerado pelo Terraform: é o que diz à VPS quem ela é
# (hosts, registry, tags de imagem, flags do ambiente). Os SEGREDOS não passam por aqui
# — o render-env.sh os busca no Secret Manager em runtime (ADR-004 §f segue valendo).
resource "google_storage_bucket_object" "env_file" {
  bucket  = google_storage_bucket.config.name
  name    = "runtime.env"
  content = var.runtime_env_content
}

# ── A instância ──────────────────────────────────────────────────────────────
resource "google_compute_instance" "this" {
  project      = var.project_id
  zone         = var.zone
  name         = "${var.name_prefix}-vm"
  machine_type = var.machine_type
  description  = "Stack completa do Turni ${var.env} (Caddy, api, admin, worker, scheduler, webapp, landing, postgres)"

  tags   = var.network_tags
  labels = merge(var.labels, { component = "vps" })

  boot_disk {
    auto_delete = true
    initialize_params {
      image  = var.boot_image
      size   = var.boot_disk_size_gb
      type   = "pd-balanced"
      labels = merge(var.labels, { component = "boot" })
    }
  }

  attached_disk {
    source      = google_compute_disk.data.id
    device_name = local.data_device_name
    mode        = "READ_WRITE"
  }

  network_interface {
    network    = var.network_self_link
    subnetwork = var.subnetwork_self_link

    access_config {
      nat_ip = google_compute_address.this.address
      # PREMIUM = backbone do Google até o edge; STANDARD economiza alguns dólares
      # ao custo de latência. Como o tráfego entra pela Cloudflare, STANDARD é
      # defensável em homolog — parametrizado.
      network_tier = var.network_tier
    }
  }

  service_account {
    email = google_service_account.vm.email
    # Escopo amplo + IAM restrito é a recomendação atual do Google (o controle fino
    # fica no IAM da SA, não no escopo do token da instância).
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    # OS Login: acesso SSH governado por IAM, sem chave pública em metadata.
    enable-oslogin = "TRUE"
    startup-script = local.startup_script
  }

  allow_stopping_for_update = true

  lifecycle {
    ignore_changes = [
      # A imagem de boot avança sozinha na família; recriar a VM por causa de um
      # bump de imagem seria downtime gratuito. Trocar de propósito = `taint`.
      boot_disk[0].initialize_params[0].image,
    ]
  }
}

# Autorização de túnel IAP restrita a ESTA instância (em vez de projeto inteiro):
# quem faz deploy em homolog não abre túnel para a VPS de prod.
resource "google_iap_tunnel_instance_iam_member" "deployer" {
  for_each = toset(var.deployer_members)

  project  = var.project_id
  zone     = var.zone
  instance = google_compute_instance.this.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = each.value
}
