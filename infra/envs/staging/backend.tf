terraform {
  backend "gcs" {
    bucket = "turni-tfstate-foodhub-87e0c"
    prefix = "staging"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.9"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# O token vem do .env da raiz, exportado como TF_VAR_cloudflare_token
# (`set -a && . .env && set +a && export TF_VAR_cloudflare_token=$CLOUDFLARE_TOKEN`).
# O MESMO token é guardado no Secret Manager e usado pelo Caddy da VPS no desafio
# DNS-01 — daí precisar de permissão Zone:DNS:Edit na zona turni.com.br.
provider "cloudflare" {
  api_token = var.cloudflare_token
}
