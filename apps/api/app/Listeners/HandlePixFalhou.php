<?php

namespace App\Listeners;

use App\Events\Pagamento\PixFalhou;
use App\Models\AuditLog;
use App\Models\PixFalha;
use App\Models\Turno;

/**
 * STORY-065 (CA-5, CA-6) — o webhook `transfer.failed` vira o ALERTA operacional: caso em
 * `pix_falhas` (fila "Pix com falha" do Backoffice — PDR-010: uma tentativa, tratamento
 * manual) + audit `pix.falhou`. Vale também quando a falha chega APÓS sucesso aparente da
 * resposta síncrona (CA-6 — o webhook é a fonte de verdade; o alerta é criado/atualizado).
 *
 * A razão exibida ao admin vem do payload do gateway (formato Pagar.me-compatível:
 * `reason` + `message`); sem razão estruturada, registramos isso honestamente em vez de
 * inventar. A chave Pix NUNCA entra aqui (o Backoffice a lê do perfil na exibição).
 */
class HandlePixFalhou
{
    public function handle(PixFalhou $event): void
    {
        if (! Turno::whereKey($event->turnoId)->exists()) {
            return; // defensivo: referência desconhecida não derruba o worker
        }

        $data = $event->payload['data'] ?? [];
        $razao = $this->razao($data);

        PixFalha::registrar($event->turnoId, $razao, $data);

        AuditLog::create([
            'actor_id' => null, // reporte do gateway (webhook)
            'action' => 'pix.falhou',
            'target_type' => 'Turno',
            'target_id' => $event->turnoId,
            'payload' => ['razao' => $razao, 'pagarme_event_id' => $event->pagarmeEventId],
        ]);
    }

    /** "reason — message" quando estruturado; senão, razão genérica honesta. */
    private function razao(array $data): string
    {
        $reason = $data['reason'] ?? null;
        $message = $data['message'] ?? null;

        return match (true) {
            $reason !== null && $message !== null => "{$reason} — {$message}",
            $reason !== null => (string) $reason,
            $message !== null => (string) $message,
            default => 'falha reportada pelo gateway (sem razão estruturada)',
        };
    }
}
