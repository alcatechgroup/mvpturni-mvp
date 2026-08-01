variable "project_id" {
  description = "ID do projeto GCP que hospeda o ambiente (FoodHub)"
  type        = string
}

variable "env" {
  description = "Ambiente (homolog | staging | prod)"
  type        = string
}

variable "name_prefix" {
  description = "Prefixo dos nomes dos recursos (convenção: turni-<env> — ver infra/README.md)"
  type        = string
}

variable "region" {
  description = "Região GCP da subnet"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR da subnet do ambiente (um /24 por ambiente, sem sobreposição)"
  type        = string
}

variable "enable_flow_logs" {
  description = "Liga VPC Flow Logs na subnet (custo de ingestão no Cloud Logging)"
  type        = bool
  default     = false
}

variable "cloudflare_ipv4_ranges" {
  description = <<-EOT
    Faixas IPv4 do proxy da Cloudflare autorizadas a alcançar 80/443 da VPS.
    Atualizar com: `curl -s https://api.cloudflare.com/client/v4/ips | jq -r '.result.ipv4_cidrs[]'`
    (a lista muda raramente; quando mudar, o sintoma é 5xx intermitente no edge).
    Snapshot em 2026-07-31 (etag 38f79d050aa027e3be3865e495dcc9bc).
  EOT
  type        = list(string)
  default = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22",
  ]
}

variable "extra_web_source_ranges" {
  description = "Faixas adicionais liberadas em 80/443 (escape hatch para depuração; manter vazio)"
  type        = list(string)
  default     = []
}
