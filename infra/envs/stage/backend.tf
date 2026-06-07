terraform {
  # Estado remoto em GCS — bucket próprio do projeto turni-stage (independência total;
  # ver runbook docs/operacao/runbook-setup-prod-e-stage.md, criado na bootstrap).
  backend "gcs" {
    bucket = "turni-stage-tfstate"
    prefix = "stage"
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
