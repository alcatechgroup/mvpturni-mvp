# Recursos COMPARTILHADOS do Turni dentro do projeto FoodHub (ADR-021).
#
# O que mora aqui é o que existe UMA vez por projeto e serve aos três ambientes:
# APIs habilitadas, o repositório de imagens e a identidade federada do CI. Separado
# dos ambientes de propósito — destruir homolog não pode levar junto o registry nem
# o WIF, e o state de prod não deve ter poder sobre eles.
#
# Ordem de aplicação: `shared` primeiro, depois `homolog` / `staging` / `prod`.

locals {
  labels = {
    app        = "turni"
    env        = "shared"
    managed-by = "terraform"
  }
}

# ── APIs necessárias no projeto ──────────────────────────────────────────────
# `disable_on_destroy = false`: o projeto é COMPARTILHADO com outras aplicações da
# FoodHub. Desabilitar uma API ao destruir um ambiente do Turni derrubaria os vizinhos.
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "oslogin.googleapis.com",
    "iap.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ── Repositório de imagens (um só, promovido entre ambientes) ────────────────
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id = var.project_id
  region     = var.region
  labels     = local.labels

  depends_on = [google_project_service.apis]
}

# ── Identidade do CI (Workload Identity Federation) ─────────────────────────
module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  github_repo = var.github_repo

  depends_on = [google_project_service.apis]
}
