<?php

namespace App\Jobs;

use App\Models\Notificacao;
use App\Services\Notificacao\EnvioEmailNotificacao;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * STORY-053 (CA-5) — envio do e-mail de UMA notificação pela fila `database`.
 *
 * Caminho PRIMÁRIO de entrega: despachado por CriarNotificacaoService quando a notificação é criada
 * e processado pelo `queue:work` que já roda em homolog/prod (Cloud Run Job + Cloud Scheduler 1/min,
 * STORY-034) — diferente de um comando agendado (`schedule:run` NÃO roda em homolog). Mesmo padrão
 * do EnviarEmailTransacionalJob da STORY-021.
 *
 * Idempotente: relê a notificação e não reenvia se já tem `enviada_email_em`/`falha_envio_em` (o
 * sweeper manual `notificacoes:enviar-emails` e um eventual redispatch convergem). 3 tentativas com
 * backoff; esgotadas, `failed()` marca `falha_envio_em` e emite o log de alerta.
 */
class EnviarEmailDaNotificacaoJob implements ShouldQueue
{
    use Queueable;

    /** ADR-011 §g — 3 tentativas. */
    public int $tries = 3;

    /** Backoff entre tentativas (s). O worker roda ~1/min, então o efetivo é ≥ esse valor. */
    public array $backoff = [10, 30, 60];

    public int $timeout = 30;

    public function __construct(public readonly int $notificacaoId)
    {
        $this->onConnection('database');
    }

    public function handle(EnvioEmailNotificacao $envio): void
    {
        $notificacao = Notificacao::query()->with('destinatario')->find($this->notificacaoId);

        // Já enviada ou em falha definitiva → nada a fazer (idempotência).
        if ($notificacao === null || $notificacao->enviada_email_em !== null || $notificacao->falha_envio_em !== null) {
            return;
        }

        $notificacao->increment('tentativas_envio');

        // Lança em falha → o framework reenfileira (tries/backoff). enviada_email_em é marcado dentro.
        $envio->enviar($notificacao);
    }

    /** Esgotadas as tentativas: marca falha definitiva e alerta (log-based metric). */
    public function failed(?Throwable $e): void
    {
        $notificacao = Notificacao::find($this->notificacaoId);

        if ($notificacao === null || $notificacao->enviada_email_em !== null) {
            return;
        }

        $notificacao->update(['falha_envio_em' => now()]);

        Log::error('notificacao.email.falhou', [
            'event' => 'notificacao.email.falhou',
            'tipo' => $notificacao->tipo->value,
            'notificacao_id' => $notificacao->id,
            'tentativas' => $notificacao->tentativas_envio,
            'causa' => $e?->getMessage(),
        ]);
    }
}
