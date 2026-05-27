terraform {
  # Estado remoto em GCS (ADR-004 — recriação do zero viável).
  # Bucket criado manualmente na bootstrap (ver runbook docs/operacao/runbook-homolog.md).
  backend "gcs" {
    bucket = "turni-terraform-state"
    prefix = "envs/homolog"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.9"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
