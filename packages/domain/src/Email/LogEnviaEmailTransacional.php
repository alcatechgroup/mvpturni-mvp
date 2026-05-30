<?php

namespace Turni\Domain\Email;

use Illuminate\Support\Facades\Log;

/**
 * Adapter de fallback: registra o despacho no log estruturado (ADR-008) sem entregar
 * e-mail. Origem STORY-019 (placeholder); STORY-021 mantém-no como adapter de teste/CI e
 * para ambientes sem provedor configurado. A entrega real é o ResendMailAdapter de cada
 * app, registrado no AppServiceProvider quando MAIL_MAILER aponta para resend/smtp.
 */
class LogEnviaEmailTransacional implements EnviaEmailTransacional
{
    public function enviar(EmailTransacional $email): void
    {
        Log::info('email.transacional.dispatched', [
            'event' => 'email.transacional.dispatched',
            'tipo' => $email->tipo->value,
            'destinatario' => $email->destinatarioMascarado(),
            'adapter' => 'log-only (sem entrega real)',
        ]);
    }
}
