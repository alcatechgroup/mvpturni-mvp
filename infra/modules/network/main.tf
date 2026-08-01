# Rede de um ambiente do Turni: VPC própria, uma subnet regional e as regras de
# firewall que definem TODA a superfície de entrada da VPS (ADR-021).
#
# Isolamento por ambiente (uma VPC por ambiente, não uma compartilhada): o projeto
# FoodHub hospeda outras aplicações, e ambiente destruído tem que sair inteiro sem
# tocar nos vizinhos. O custo de uma VPC é zero.
#
# Ingress: o GCP nega tudo por padrão. Só existem duas portas de entrada —
#   1. 80/443 vindos EXCLUSIVAMENTE das faixas do proxy da Cloudflare;
#   2. 22 vindo do range do IAP (35.235.240.0/20), para SSH sem porta aberta ao mundo.
# O IP externo da VPS é, portanto, inalcançável fora desses dois caminhos.

locals {
  tag_web = "${var.name_prefix}-web"
  tag_ssh = "${var.name_prefix}-ssh"

  # Range fixo do TCP forwarding do IAP (documentado pelo Google, não muda).
  iap_range = "35.235.240.0/20"
}

resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  description             = "VPC do ambiente ${var.env} do Turni"
}

resource "google_compute_subnetwork" "this" {
  project       = var.project_id
  region        = var.region
  name          = "${var.name_prefix}-subnet"
  network       = google_compute_network.this.self_link
  ip_cidr_range = var.subnet_cidr

  # Logs de fluxo desligados por padrão: em homolog o volume não paga o custo.
  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_10_MIN"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# ── Ingress 80/443: só da Cloudflare ─────────────────────────────────────────
# Sem isto o mundo alcança o origin direto e contorna WAF/rate limit da Cloudflare
# (e o `Full (strict)` vira teatro). A lista vem de https://api.cloudflare.com/client/v4/ips
# — ver var.cloudflare_ipv4_ranges para o procedimento de atualização.
resource "google_compute_firewall" "web" {
  project     = var.project_id
  name        = "${var.name_prefix}-fw-web"
  network     = google_compute_network.this.self_link
  description = "HTTP/HTTPS somente das faixas do proxy da Cloudflare"
  direction   = "INGRESS"
  priority    = 1000

  source_ranges = concat(var.cloudflare_ipv4_ranges, var.extra_web_source_ranges)
  target_tags   = [local.tag_web]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

# ── Ingress 22: só via IAP ───────────────────────────────────────────────────
# `gcloud compute ssh --tunnel-through-iap` entra por aqui. Nenhuma porta 22 exposta
# à internet e nenhuma chave de longa duração: a autorização é IAM (ver módulo iam).
resource "google_compute_firewall" "ssh_iap" {
  project     = var.project_id
  name        = "${var.name_prefix}-fw-ssh-iap"
  network     = google_compute_network.this.self_link
  description = "SSH exclusivamente pelo TCP forwarding do IAP"
  direction   = "INGRESS"
  priority    = 1000

  source_ranges = [local.iap_range]
  target_tags   = [local.tag_ssh]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# ── Negação explícita de todo o resto ────────────────────────────────────────
# Redundante com o default implícito do GCP, mas deixa a intenção auditável e
# garante que uma regra futura de prioridade alta não abra a VPS por descuido.
resource "google_compute_firewall" "deny_all_ingress" {
  project     = var.project_id
  name        = "${var.name_prefix}-fw-deny-ingress"
  network     = google_compute_network.this.self_link
  description = "Nega qualquer ingress não coberto pelas regras acima"
  direction   = "INGRESS"
  priority    = 65534

  source_ranges = ["0.0.0.0/0"]

  deny {
    protocol = "all"
  }
}
