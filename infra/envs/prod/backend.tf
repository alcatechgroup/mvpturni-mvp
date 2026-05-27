terraform {
  # PRODUÇÃO — aplicar somente no EPIC-006 (gate humano obrigatório antes de qualquer apply).
  backend "gcs" {
    bucket = "turni-terraform-state"
    prefix = "envs/prod"
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
