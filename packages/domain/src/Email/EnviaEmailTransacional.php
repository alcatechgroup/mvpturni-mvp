<?php

namespace Turni\Domain\Email;

/**
 * Anti-Corruption Layer de e-mail transacional (ADR-011 §b; IDR-015).
 *
 * O domínio fala seu vocabulário (TipoEmail::AprovacaoConcedida); o adapter concreto
 * traduz para o SDK do provedor. Nenhuma camada acima do adapter conhece o Resend.
 *
 * Vive em packages/domain (Turni\Domain\Email) para ser compartilhado por `api` e
 * `admin` — a fila `database` é cross-app (worker roda no api; aprovação despacha do
 * admin), então o contrato precisa do mesmo FQCN nos dois apps (IDR-015).
 */
interface EnviaEmailTransacional
{
    /**
     * @throws EmailTransacionalException quando o provedor falha (o job aplica retry/backoff).
     */
    public function enviar(EmailTransacional $email): void;
}
