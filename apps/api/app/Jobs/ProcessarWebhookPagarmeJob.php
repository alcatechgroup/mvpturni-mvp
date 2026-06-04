<?php

namespace App\Jobs;

use App\Domain\Pagamento\Webhook\PagarmeWebhookValidator;
use App\Models\WebhookEventoPagarme;
use App\Support\Telemetry\PagamentoEvents;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * STORY-056 / ADR-016 (CA-6, e). Processa um webhook do Pagar.me JÁ validado e persistido (o
 * controller respondeu 200 rápido). Roda no `worker` (fila `database`, ADR-002): mapeia o tipo
 * do evento do provedor → evento de DOMÍNIO canônico e o dispara para os listeners de
 * STORY-065 (captura+Pix) e STORY-067 (notificações).
 *
 * Idempotente: só processa eventos ainda sem `processado_em` (a dedup por event_id já barrou
 * a repetição na entrada; isto cobre o redispatch do próprio job). 3 tentativas com backoff.
 */
class ProcessarWebhookPagarmeJob implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public array $backoff = [10, 30, 60];

    public int $timeout = 30;

    public function __construct(public readonly string $eventId)
    {
        $this->onConnection('database');
    }

    public function handle(PagarmeWebhookValidator $validator): void
    {
        $evento = WebhookEventoPagarme::where('event_id', $this->eventId)->first();

        if ($evento === null || $evento->processado_em !== null) {
            return; // desconhecido ou já processado (idempotência)
        }

        $inicio = microtime(true);
        $payload = $evento->payload;
        $turnoId = $validator->turnoId($payload);
        $eventoDominioClasse = $validator->eventoDominio($payload);

        // Tipo desconhecido do provedor: aceitamos sem quebrar (variabilidade do externo —
        // integration-architecture.md). Marca processado e segue.
        if ($eventoDominioClasse !== null && $turnoId !== null) {
            event(new $eventoDominioClasse($turnoId, $this->eventId, $payload));
        }

        $evento->update(['processado_em' => now()]);

        PagamentoEvents::webhookProcessado(
            eventoDominio: $eventoDominioClasse ? class_basename($eventoDominioClasse) : 'desconhecido',
            turnoId: $turnoId,
            pagarmeEventId: $this->eventId,
            latenciaMs: (int) round((microtime(true) - $inicio) * 1000),
        );
    }
}
