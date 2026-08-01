# Artifact Registry — repositório Docker do Turni dentro do projeto FoodHub.
#
# UM repositório para os TRÊS ambientes (não um por ambiente): a mesma imagem
# imutável, identificada pela tag de release, é promovida de homolog → staging →
# prod. Reconstruir por ambiente destruiria a garantia de "o que testei é o que
# subiu". O isolamento entre ambientes está no dado e na rede, não no binário.
#
# O nome `turni` é o prefixo de aplicação: num projeto que hospeda outras apps da
# FoodHub, a listagem de repositórios diz de quem é cada coisa.

resource "google_artifact_registry_repository" "turni" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  format        = "DOCKER"
  description   = "Imagens Docker do Turni (api, admin, webapp, landing, caddy, pagarme-mock)"
  labels        = var.labels

  # Higiene de custo: mantém as versões recentes de cada imagem e descarta o resto.
  # `keep_count` age por pacote (imagem), não no repositório inteiro.
  cleanup_policies {
    id     = "manter-versoes-recentes"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_versions
    }
  }

  cleanup_policies {
    id     = "apagar-nao-tagueadas"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "${var.untagged_ttl_days * 24}h"
    }
  }

  cleanup_policy_dry_run = var.cleanup_dry_run
}
