<?php

namespace App\Listeners;

use App\Events\Pagamento\PixEnviado;
use App\Models\AuditLog;
use App\Models\Turno;

/**
 * STORY-065 (CA-4, CA-6) — o webhook `transfer.paid` do gateway é a FONTE DE VERDADE da
 * confirmação do Pix. Este handler materializa essa verdade no audit log `pix.enviado`,
 * que é o que liga: (a) o evento "Pix enviado" na timeline da 060 (whitelist já mapeada),
 * (b) o "Pix enviado em HH:MM" do card de valor (payload `pix{}` do detalhe — CA-4).
 *
 * Idempotente por turno: redelivery do provedor (event_id novo, mesmo Pix) não duplica a
 * linha da timeline — PDR-010 garante um único Pix por turno.
 *
 * NÃO fecha caso aberto em `pix_falhas`: resolução é decisão humana auditada (CA-8).
 */
class HandlePixEnviado
{
    public function handle(PixEnviado $event): void
    {
        if (! Turno::whereKey($event->turnoId)->exists()) {
            return; // defensivo: referência desconhecida não derruba o worker
        }

        if (AuditLog::where('action', 'pix.enviado')->where('target_id', $event->turnoId)->exists()) {
            return; // redelivery: a timeline já tem a linha
        }

        $turno = Turno::find($event->turnoId);

        AuditLog::create([
            'actor_id' => null, // confirmação do gateway (webhook)
            'action' => 'pix.enviado',
            'target_type' => 'Turno',
            'target_id' => $event->turnoId,
            'payload' => [
                'pagarme_transfer_id' => $event->payload['data']['transfer_id'] ?? null,
                'valor' => $turno->valor,
                'pagarme_event_id' => $event->pagarmeEventId,
            ],
        ]);
    }
}
