<?php

namespace App\Email;

use App\Mail\TransacionalMail;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;
use Turni\Domain\Email\EmailTransacional;
use Turni\Domain\Email\EmailTransacionalException;
use Turni\Domain\Email\EnviaEmailTransacional;

/**
 * Adapter concreto da ACL de e-mail (ADR-011 §b; IDR-015).
 *
 * Único ponto que conhece o Laravel Mail. O provedor real (Resend em
 * homolog/prod, Mailpit em dev) é selecionado por `MAIL_MAILER` — troca de
 * provedor é config, não troca de classe (ADR-011 §c). Nenhuma camada acima
 * conhece o Resend.
 *
 * Log estruturado mascarado por envio (ADR-008): `email.sent` / `email.failed`
 * — nunca o e-mail em claro nem o corpo. Exceções do transporte são relançadas
 * como EmailTransacionalException para o job aplicar retry/backoff/dead-letter
 * (ADR-011 §g).
 */
class MailEnviaEmailTransacional implements EnviaEmailTransacional
{
    public function enviar(EmailTransacional $email): void
    {
        $inicio = microtime(true);

        try {
            $enviado = Mail::to($email->destinatario)->send(new TransacionalMail($email));

            Log::info('email.sent', [
                'event' => 'email.sent',
                'tipo' => $email->tipo->value,
                'destinatario' => $email->destinatarioMascarado(),
                'message_id' => $enviado?->getMessageId(),
                'latencia_ms' => (int) round((microtime(true) - $inicio) * 1000),
            ]);
        } catch (Throwable $e) {
            Log::error('email.failed', [
                'event' => 'email.failed',
                'tipo' => $email->tipo->value,
                'destinatario' => $email->destinatarioMascarado(),
                'causa' => $e->getMessage(),
                'latencia_ms' => (int) round((microtime(true) - $inicio) * 1000),
            ]);

            throw new EmailTransacionalException(
                "Falha ao enviar e-mail transacional ({$email->tipo->value}).",
                previous: $e,
            );
        }
    }
}
