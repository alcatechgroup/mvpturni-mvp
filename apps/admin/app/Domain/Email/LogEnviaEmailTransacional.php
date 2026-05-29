<?php

namespace App\Domain\Email;

use Illuminate\Support\Facades\Log;

/**
 * Adapter placeholder de STORY-019: registra o despacho no log estruturado (ADR-008),
 * sem entregar e-mail de verdade. O conteúdo e a entrega real (Resend/Mailpit) são
 * responsabilidade de STORY-021, que substitui este binding pelo adapter Resend.
 *
 * Mantém o contrato da ACL vivo e satisfaz CA-7 ("basta o dispatch acontecer e o log
 * estruturado registrar") sem antecipar decisões de STORY-021.
 */
class LogEnviaEmailTransacional implements EnviaEmailTransacional
{
    public function enviar(EmailTransacional $email): void
    {
        Log::info('email.transacional.dispatched', [
            'event' => 'email.transacional.dispatched',
            'tipo' => $email->tipo->value,
            'destinatario' => $email->destinatarioMascarado(),
            'adapter' => 'log-only (STORY-019 placeholder; entrega real em STORY-021)',
        ]);
    }
}
