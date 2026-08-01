variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
}

variable "name_prefix" {
  description = "Prefixo dos secret_id (convenção: turni-<env>)"
  type        = string
}

variable "labels" {
  description = "Labels aplicadas aos segredos"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = <<-EOT
    Mapa papel => valor. O papel vira o sufixo do secret_id (`<name_prefix>-<papel>`)
    e é a chave usada pelo render-env.sh da VPS para mapear segredo => variável de
    ambiente. Todo papel declarado recebe uma versão: para não gerenciar um segredo
    pelo Terraform, basta não declará-lo aqui (é o que prod faz com os segredos do
    fake de pagamento).
  EOT
  type        = map(string)
  sensitive   = true
}
