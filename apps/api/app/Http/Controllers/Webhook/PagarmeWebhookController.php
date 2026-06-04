<?php

namespace App\Http\Controllers\Webhook;

use App\Domain\Pagamento\Webhook\PagarmeWebhookValidator;
use App\Http\Controllers\Controller;
use App\Jobs\ProcessarWebhookPagarmeJob;
use App\Models\WebhookEventoPagarme;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-056 / ADR-016 (CA-6, e). Webhook entrante do Pagar.me. PÚBLICO (fora de auth/sessão —
 * é o provedor que chama, não o WebApp), no `api` (Cloud Run, southamerica-east1 — ADR-004).
 *
 * Fluxo seguro e rápido (integration-architecture.md §webhook):
 *  1. Valida a assinatura HMAC do corpo BRUTO — inválida → 401, sem processar.
 *  2. Deduplica por event_id (at-least-once delivery) — repetição → 200 sem reprocessar.
 *  3. Persiste e ENFILEIRA o processamento (worker), respondendo 200 imediatamente — o provedor
 *     não pode timeoutar esperando o processamento síncrono.
 */
class PagarmeWebhookController extends Controller
{
    public function __invoke(Request $request, PagarmeWebhookValidator $validator): JsonResponse
    {
        $raw = $request->getContent();

        if (! $validator->assinaturaValida($raw, $request->header('X-Pagarme-Signature'))) {
            return response()->json(['erro' => 'assinatura inválida'], 401);
        }

        $payload = json_decode($raw, true) ?: [];
        $eventId = $validator->eventId($payload);

        if ($eventId === null) {
            return response()->json(['erro' => 'event id ausente'], 422);
        }

        // firstOrCreate é atômico sobre o índice único event_id: a 2ª recepção do mesmo evento
        // recebe a linha existente (wasRecentlyCreated = false) e NÃO reprocessa.
        $registro = WebhookEventoPagarme::firstOrCreate(
            ['event_id' => $eventId],
            [
                'tipo' => $payload['type'] ?? null,
                'turno_id' => $validator->turnoId($payload),
                'payload' => $payload,
                'recebido_em' => now(),
            ],
        );

        if (! $registro->wasRecentlyCreated) {
            return response()->json(['status' => 'duplicado'], 200);
        }

        ProcessarWebhookPagarmeJob::dispatch($eventId);

        return response()->json(['status' => 'recebido'], 200);
    }
}
