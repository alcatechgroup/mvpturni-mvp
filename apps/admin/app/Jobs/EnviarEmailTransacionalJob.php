<?php

namespace App\Jobs;

use App\Domain\Email\EmailTransacional;
use App\Domain\Email\EnviaEmailTransacional;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Despacho assíncrono de e-mail transacional pela fila `database` (ADR-011 §g — nunca
 * síncrono no request HTTP). 3 tentativas com backoff exponencial.
 *
 * O worker resolve o adapter da ACL e chama enviar(). STORY-019 usa o adapter log-only;
 * STORY-021 troca pelo Resend sem mudar este job.
 */
class EnviarEmailTransacionalJob implements ShouldQueue
{
    use Queueable;

    /** ADR-011 §g — 3 tentativas. */
    public int $tries = 3;

    /** ADR-011 §g — backoff exponencial 30s → 5min → 30min. */
    public array $backoff = [30, 300, 1800];

    /** ADR-011 §g — timeout adequado à API síncrona do Resend. */
    public int $timeout = 30;

    public function __construct(public readonly EmailTransacional $email)
    {
        // Fila `database` (ADR-002 — sem Redis no MVP).
        $this->onConnection('database');
    }

    public function handle(EnviaEmailTransacional $gateway): void
    {
        $gateway->enviar($this->email);
    }
}
