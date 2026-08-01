# Registros DNS do ambiente na Cloudflare (ADR-021).
#
# SUBDOMÍNIOS ACHATADOS — restrição dura do Universal SSL da Cloudflare, que emite
# certificado para o apex e UM nível de subdomínio (`*.turni.com.br`), não para dois
# (`*.homolog.turni.com.br`). Por isso `app-homolog.turni.com.br`, não
# `app.homolog.turni.com.br`. Cobrir dois níveis exigiria Advanced Certificate Manager
# (pago) — não se justifica no MVP. Ver ADR-021 §c.
#
# Todos os registros de aplicação são A apontando para o IP da VPS, com o proxy
# LIGADO: é o proxy que esconde o origin, aplica WAF/rate limit e permite o firewall
# do GCP restringir 80/443 às faixas da Cloudflare.
#
# Modo de TLS esperado na zona: Full (strict). O Caddy da VPS obtém certificado
# público válido por DNS-01 usando o mesmo token — logo o hop Cloudflare→origin é
# verificável, sem certificado auto-assinado e sem o modo "Flexible".

resource "cloudflare_dns_record" "app" {
  for_each = var.a_records

  zone_id = var.zone_id
  name    = each.value
  type    = "A"
  content = var.ip
  ttl     = 1 # 1 = automático; obrigatório quando proxied
  proxied = var.proxied
  comment = "turni/${var.env} — ${each.key} (gerenciado por Terraform)"
}

# ── Domínio remetente de e-mail (Resend — ADR-011 §e) ────────────────────────
# Registros de verificação/entrega. Nunca proxied: proxy da Cloudflare é HTTP, e
# MX/TXT proxiado simplesmente não funciona.

resource "cloudflare_dns_record" "mail_mx" {
  count = var.mail_sender_host == null ? 0 : 1

  zone_id  = var.zone_id
  name     = "send.${var.mail_sender_host}"
  type     = "MX"
  content  = var.mail_mx_target
  priority = 10
  ttl      = 3600
  comment  = "turni/${var.env} — bounce/feedback do Resend"
}

resource "cloudflare_dns_record" "mail_spf" {
  count = var.mail_sender_host == null ? 0 : 1

  zone_id = var.zone_id
  name    = "send.${var.mail_sender_host}"
  type    = "TXT"
  content = "\"v=spf1 include:amazonses.com ~all\""
  ttl     = 3600
  comment = "turni/${var.env} — SPF do Resend"
}

resource "cloudflare_dns_record" "mail_dkim" {
  count = var.mail_sender_host == null || var.mail_dkim_value == null ? 0 : 1

  zone_id = var.zone_id
  name    = "resend._domainkey.${var.mail_sender_host}"
  type    = "TXT"
  content = "\"${var.mail_dkim_value}\""
  ttl     = 3600
  comment = "turni/${var.env} — DKIM do Resend (chave pública)"
}

resource "cloudflare_dns_record" "mail_dmarc" {
  count = var.mail_sender_host == null || !var.mail_dmarc_enabled ? 0 : 1

  zone_id = var.zone_id
  name    = "_dmarc.${var.mail_sender_host}"
  type    = "TXT"
  content = "\"v=DMARC1; p=none;\""
  ttl     = 3600
  comment = "turni/${var.env} — DMARC em modo observação"
}
