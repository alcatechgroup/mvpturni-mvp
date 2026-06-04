<?php

namespace App\Domain\Pagamento\Webhook;

use App\Events\Pagamento\CapturaConfirmada;
use App\Events\Pagamento\PixEnviado;
use App\Events\Pagamento\PixFalhou;
use App\Events\Pagamento\PreAutorizacaoCriada;
use App\Events\Pagamento\PreAutorizacaoLiberada;

/**
 * STORY-056 / ADR-016 (CA-6, e) — NÚCLEO da validação e do parsing do webhook entrante. Sem
 * dependência de HTTP/banco: funções puras testáveis com 98% de cobertura.
 *
 * Faz três coisas:
 *  1. Valida a assinatura HMAC-SHA256 do corpo (hash_equals, sem timing leak) — inválida → 401.
 *  2. Extrai `event_id` (dedup) e `turno_id` (external_reference, ADR-018) do payload.
 *  3. Mapeia o `type` do evento Pagar.me para o evento de DOMÍNIO canônico (CA-6). Tipo
 *     desconhecido → null (o webhook é aceito com 200, mas não emite evento — não quebramos
 *     por evento extra do provedor; `integration-architecture.md` §variabilidade).
 */
class PagarmeWebhookValidator
{
    public function __construct(private readonly string $secret) {}

    /** Assinatura HMAC do corpo bruto. Comparação resistente a timing (hash_equals). */
    public function assinaturaValida(string $rawBody, ?string $assinatura): bool
    {
        if ($assinatura === null || $assinatura === '') {
            return false;
        }

        $esperada = hash_hmac('sha256', $rawBody, $this->secret);

        return hash_equals($esperada, $assinatura);
    }

    /** id do evento no provedor — chave de deduplicação (at-least-once delivery). */
    public function eventId(array $payload): ?string
    {
        $id = $payload['id'] ?? null;

        return is_string($id) && $id !== '' ? $id : null;
    }

    /** UUID do turno, carregado no external_reference (ADR-018, CA-5). */
    public function turnoId(array $payload): ?string
    {
        $ref = $payload['data']['external_reference'] ?? null;

        return is_string($ref) && $ref !== '' ? $ref : null;
    }

    /**
     * Mapeia o tipo do evento Pagar.me → FQCN do evento de domínio (CA-6). Null se desconhecido.
     *
     * @return class-string|null
     */
    public function eventoDominio(array $payload): ?string
    {
        return match ($payload['type'] ?? null) {
            'charge.pending', 'charge.authorized' => PreAutorizacaoCriada::class,
            'charge.paid', 'charge.captured' => CapturaConfirmada::class,
            'transfer.paid', 'transfer.created' => PixEnviado::class,
            'transfer.failed' => PixFalhou::class,
            'charge.canceled', 'charge.refunded' => PreAutorizacaoLiberada::class,
            default => null,
        };
    }
}
