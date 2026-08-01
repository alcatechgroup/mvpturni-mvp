# Um ambiente completo do Turni: rede, VPS, segredos, DNS e observabilidade.
#
# Por que os ambientes são um MÓDULO e não três cópias de HCL: homolog, staging e
# prod só devem diferir nos VALORES (host, tamanho da máquina, flags de negócio).
# Com três arquivos irmãos, a diferença vira acidente — alguém corrige homolog e
# esquece prod, e o ambiente de teste deixa de testar a produção. Aqui, o env é uma
# chamada de ~40 linhas e a estrutura é a mesma por construção.
#
# Depende dos recursos COMPARTILHADOS (infra/envs/shared): Artifact Registry, WIF e a
# SA do CI. Estes existem uma vez por projeto e são referenciados por valor.

locals {
  name_prefix = "turni-${var.env}"

  labels = merge(
    {
      app        = "turni"
      env        = var.env
      managed-by = "terraform"
    },
    var.extra_labels,
  )

  # Hosts ACHATADOS (ADR-021 §c) — um nível de subdomínio, limite do Universal SSL.
  hosts = {
    webapp  = var.hosts.webapp
    admin   = var.hosts.admin
    api     = var.hosts.api
    landing = var.hosts.landing
  }

  mail_from_address = "no-reply@${var.mail_sender_host}.${var.dns_zone_name}"

  # Registros A: papel => nome relativo à zona. O apex entra como o próprio nome da
  # zona (a Cloudflare aceita o FQDN e resolve para o root).
  a_records = {
    for role, fqdn in local.hosts :
    role => trimsuffix(fqdn, ".${var.dns_zone_name}") == fqdn ? var.dns_zone_name : trimsuffix(fqdn, ".${var.dns_zone_name}")
  }

  runtime_env = templatefile("${path.module}/templates/runtime.env.tftpl", {
    env               = var.env
    project_id        = var.project_id
    region            = var.region
    registry          = var.registry_url
    image_tag         = var.default_image_tag
    name_prefix       = local.name_prefix
    webapp_host       = local.hosts.webapp
    admin_host        = local.hosts.admin
    api_host          = local.hosts.api
    landing_host      = local.hosts.landing
    mail_from_address = local.mail_from_address
    mail_from_name    = var.mail_from_name
    db_name           = var.db_name
    db_user           = var.db_user
    data_dir          = var.data_mount_point
    # Mesma fórmula do módulo vps. Referenciar o output criaria ciclo: o módulo vps
    # recebe este conteúdo como entrada.
    config_bucket                 = "${local.name_prefix}-config-${var.project_id}"
    backups_bucket                = "${local.name_prefix}-backups-${var.project_id}"
    acme_email                    = var.acme_email
    enable_payment_fake           = var.enable_payment_fake
    pagarme_mock_pix_resultado    = var.pagarme_mock_pix_resultado
    pagarme_mock_pix_sla_segundos = var.pagarme_mock_pix_sla_segundos
    business_env                  = var.business_env
  })
}

# ── Rede ─────────────────────────────────────────────────────────────────────
module "network" {
  source = "../network"

  project_id       = var.project_id
  env              = var.env
  name_prefix      = local.name_prefix
  region           = var.region
  subnet_cidr      = var.subnet_cidr
  enable_flow_logs = var.enable_flow_logs
}

# ── Segredos ─────────────────────────────────────────────────────────────────
module "secrets" {
  source = "../secrets"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  labels      = local.labels
  secrets     = var.secrets
}

# ── VPS ──────────────────────────────────────────────────────────────────────
module "vps" {
  source = "../vps"

  project_id  = var.project_id
  env         = var.env
  name_prefix = local.name_prefix
  region      = var.region
  zone        = var.zone
  labels      = local.labels

  machine_type      = var.machine_type
  boot_disk_size_gb = var.boot_disk_size_gb
  data_disk_size_gb = var.data_disk_size_gb
  data_mount_point  = var.data_mount_point
  network_tier      = var.network_tier

  network_self_link    = module.network.network_self_link
  subnetwork_self_link = module.network.subnetwork_self_link
  network_tags         = [module.network.tag_web, module.network.tag_ssh]

  accessible_secret_ids = module.secrets.secret_id_list
  deployer_members      = var.deployer_members

  runtime_source_dir  = var.runtime_source_dir
  runtime_env_content = local.runtime_env

  backup_retention_days = var.backup_retention_days
  install_ops_agent     = var.install_ops_agent
}

# ── DNS na Cloudflare ────────────────────────────────────────────────────────
module "dns" {
  source = "../cloudflare-dns"

  zone_id   = var.dns_zone_id
  env       = var.env
  ip        = module.vps.external_ip
  a_records = local.a_records
  proxied   = var.dns_proxied

  mail_sender_host = "${var.mail_sender_host}.${var.dns_zone_name}"
  mail_dkim_value  = var.mail_dkim_value
}

# ── Observabilidade ──────────────────────────────────────────────────────────
module "monitoring" {
  source = "../monitoring"

  project_id           = var.project_id
  env                  = var.env
  alert_email          = var.alert_email
  enable_uptime_checks = var.enable_uptime_checks
  enable_vps_alerts    = var.enable_vps_alerts

  uptime_targets = {
    api     = { host = local.hosts.api, path = "/health" }
    admin   = { host = local.hosts.admin, path = "/health" }
    webapp  = { host = local.hosts.webapp, path = "/health" }
    landing = { host = local.hosts.landing, path = "/" }
  }
}
