terraform {
  # State remoto em GCS, um bucket para o Turni inteiro e um prefixo por camada.
  # O bucket é criado na bootstrap (ver docs/operacao/runbook-vps.md §bootstrap).
  backend "gcs" {
    bucket = "turni-tfstate-foodhub-87e0c"
    prefix = "shared"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.9"
}

provider "google" {
  project = var.project_id
  region  = var.region
}
