# Secret Manager — cofre de segredos do ambiente (ADR-004 §f, mantido pela ADR-021).
#
# Mesmo com a stack rodando numa VPS, os segredos NÃO moram na máquina: o
# `render-env.sh` os busca em runtime com a identidade da instância e escreve um
# .env com permissão 600, que nunca é versionado nem enviado ao bucket de config.
#
# O módulo é genérico de propósito (um mapa papel => valor): acrescentar um segredo
# é uma linha no env, sem editar módulo. O papel vira o sufixo do secret_id, então o
# nome final é `turni-<env>-<papel>` — auditável na listagem de um projeto que
# hospeda outras aplicações da FoodHub.

locals {
  # `for_each` não aceita argumento derivado de valor sensível (a chave da instância
  # apareceria em texto claro nos endereços do plano). Os NOMES dos segredos não são
  # segredo — estão no console do GCP e no runtime.env —, então `nonsensitive` sobre
  # as chaves é seguro e é o escape hatch previsto para exatamente este caso. Os
  # VALORES seguem sensíveis: só aparecem em `secret_data`, abaixo.
  secret_names = nonsensitive(toset(keys(var.secrets)))
}

resource "google_secret_manager_secret" "this" {
  for_each = local.secret_names

  project   = var.project_id
  secret_id = "${var.name_prefix}-${each.value}"
  labels    = merge(var.labels, { component = "secret" })

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "this" {
  for_each = local.secret_names

  secret      = google_secret_manager_secret.this[each.value].id
  secret_data = var.secrets[each.value]
}
