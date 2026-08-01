variable "zone_id" {
  description = "ID da zona turni.com.br na Cloudflare"
  type        = string
}

variable "env" {
  description = "Ambiente (homolog | staging | prod) — só entra no comment dos registros"
  type        = string
}

variable "ip" {
  description = "IP público estático da VPS do ambiente"
  type        = string
}

variable "a_records" {
  description = <<-EOT
    Registros A do ambiente: papel => host. O host é o nome ACHATADO relativo à zona
    (ex.: "app-homolog"), ou "turni.com.br" para o apex.
    Ex.: { app = "app-homolog", admin = "admin-homolog", api = "api-homolog", landing = "homolog" }
  EOT
  type        = map(string)
}

variable "proxied" {
  description = "Passa o tráfego pelo proxy da Cloudflare (esconde o origin, habilita WAF). Desligar quebra a regra de firewall que só aceita faixas da Cloudflare."
  type        = bool
  default     = true
}

variable "mail_sender_host" {
  description = "Host remetente do e-mail transacional, achatado (ex.: mail-homolog). null desliga o bloco de e-mail."
  type        = string
  default     = null
}

variable "mail_mx_target" {
  description = "MX de feedback do Resend para a região do domínio"
  type        = string
  default     = "feedback-smtp.sa-east-1.amazonses.com"
}

variable "mail_dkim_value" {
  description = "Valor do DKIM público fornecido pelo Resend (dado público de DNS)"
  type        = string
  default     = null
}

variable "mail_dmarc_enabled" {
  description = "Publica um DMARC em p=none (observação) para o domínio remetente"
  type        = bool
  default     = true
}
