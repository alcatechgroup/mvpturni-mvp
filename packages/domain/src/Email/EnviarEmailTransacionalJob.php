<?php

namespace Turni\Domain\Email;

use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

/**
 * Despacho assíncrono de e-mail transacional pela fila `database` (ADR-011 §g — nunca
 * síncrono no request HTTP). 3 tentativas com backoff exponencial.
 *
 * Vive em packages/domain (IDR-015) para que o worker do `api` deserialize jobs
 * despachados pelo `admin` — mesmo FQCN nos dois apps. O worker resolve o adapter da ACL
 * do container e chama enviar(); cada app registra o binding (Resend em prod/homolog,
 * SMTP/Mailpit em dev).
 *
 * ShouldBeUnique implementa a idempotência (CA-14): com EmailTransacional::idempotencyKey
 * preenchida (convenção "<tipo>:<user_id>"), dois despachos idênticos viram um só — o
 * segundo não adquire o lock e nem é enfileirado.
 */
class EnviarEmailTransacionalJob implements ShouldBeUnique, ShouldQueue
{
    use Queueable;

    /** ADR-011 §g — 3 tentativas. */
    public int $tries = 3;

    /** ADR-011 §g — backoff exponencial 30s → 5min → 30min. */
    public array $backoff = [30, 300, 1800];

    /** ADR-011 §g — timeout adequado à API síncrona do Resend. */
    public int $timeout = 30;

    /** Janela do lock de unicidade (CA-14): 24h cobre o despacho duplicado da mesma aprovação. */
    public int $uniqueFor = 86400;

    public function __construct(public readonly EmailTransacional $email)
    {
        // Fila `database` (ADR-002 — sem Redis no MVP).
        $this->onConnection('database');
    }

    /**
     * Chave de unicidade (CA-14). Com idempotencyKey → deduplica; sem ela → valor
     * aleatório por despacho (não deduplica, ex.: cada pedido de reset de senha é único).
     */
    public function uniqueId(): string
    {
        return $this->email->idempotencyKey ?? (string) Str::uuid();
    }

    public function handle(EnviaEmailTransacional $gateway): void
    {
        $gateway->enviar($this->email);
    }

    /**
     * Esgotadas as tentativas, o job vai para `failed_jobs` (dead letter). Emite log
     * estruturado mascarado que alimenta o alerta do Cloud Monitoring (ADR-008): ERROR
     * para o fluxo crítico (aprovação/reset), WARNING para o lembrete (ADR-011 §g).
     * `email.aprovacao.falhou` é o evento que a métrica de alerta observa.
     */
    public function failed(?Throwable $e): void
    {
        [$nivel, $evento] = match ($this->email->tipo) {
            TipoEmail::AprovacaoConcedida => ['error', 'email.aprovacao.falhou'],
            TipoEmail::RecuperacaoSenha => ['error', 'email.recuperacao.falhou'],
            TipoEmail::LembreteCompletarCadastro => ['warning', 'email.lembrete.falhou'],
        };

        Log::log($nivel, $evento, [
            'event' => $evento,
            'tipo' => $this->email->tipo->value,
            'destinatario' => $this->email->destinatarioMascarado(),
            'causa' => $e?->getMessage(),
        ]);
    }
}
