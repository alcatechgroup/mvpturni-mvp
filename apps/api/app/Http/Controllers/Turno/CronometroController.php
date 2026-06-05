<?php

namespace App\Http\Controllers\Turno;

use App\Enums\TurnoStatus;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Turno;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-057/063 / ADR-017 (decisão a) — âncora do cronômetro bilateral (GET /api/turnos/{turno}/cronometro).
 *
 * O servidor é a ÚNICA fonte de verdade do tempo decorrido (CA-4): NÃO conta tiques nem mantém
 * estado de conexão. Devolve a âncora (`iniciado_em` = `check_in_at`, carimbado na transição
 * `aguardando_checkin → ativo`), o `encerrado_em` (`check_out_at`, na transição para finalizado) e a
 * sua própria hora (`servidor_agora`). Cada cliente calcula `offset = cliente_agora − servidor_agora`,
 * tica LOCALMENTE `decorrido = (cliente_agora − offset) − iniciado_em` e faz polling curto
 * (`polling_segundos`, config — CA-1 "configurável") só para reconciliar o offset e detectar a
 * saída de `ativo`. Dois clientes ancorados no MESMO `iniciado_em` ficam sincronizados ≤ 2s por
 * construção — sem WebSocket, sem SSE, sem infra nova (fit com Cloud Run stateless, ADR-004).
 *
 * Em `aguardando_checkout` (CA-5) o modelo ainda não tem `check_out_at` (ADR-015 só o carimba na
 * transição → finalizado); o encerramento EXIBIDO deriva do evento `turno.checkout_solicitado` do
 * audit log — assim a "duração final" congela IDÊNTICA nos dois lados (a 064 grava esse evento).
 *
 * RBAC: só os dois lados do turno (profissional e contratante) leem o cronômetro; terceiros → 404
 * (não revela existência). Instantes em ISO-8601 UTC (a fronteira local↔UTC é do cliente — IDR-026).
 */
class CronometroController extends Controller
{
    public function show(Request $request, Turno $turno): JsonResponse
    {
        $user = $request->user();
        abort_unless(
            $user !== null && in_array($user->id, [$turno->profissional_id, $turno->contratante_id], true),
            404,
        );

        return response()->json([
            'estado' => $turno->status->value,
            'iniciado_em' => $turno->check_in_at?->toIso8601String(),
            'encerrado_em' => $this->encerradoEm($turno),
            'servidor_agora' => now()->toIso8601String(),
            'polling_segundos' => max(1, (int) config('turno.cronometro_polling_segundos')),
            // Geofencing de check-in é ação do PROFISSIONAL (PDR-008); o contratante valida o PIN.
            // A PoC usa isto para só oferecer a captura ao lado certo.
            'sou_profissional' => $user->id === $turno->profissional_id,
        ]);
    }

    /**
     * Instante de encerramento da CONTAGEM exibida: `check_out_at` quando já carimbado
     * (finalizado*); em `aguardando_checkout`, o momento da solicitação do check-out
     * (audit log) — duração final bilateralmente idêntica (CA-5). `null` enquanto `ativo`.
     */
    private function encerradoEm(Turno $turno): ?string
    {
        if ($turno->check_out_at !== null) {
            return $turno->check_out_at->toIso8601String();
        }

        if ($turno->status !== TurnoStatus::AguardandoCheckout) {
            return null;
        }

        return AuditLog::query()
            ->where('target_type', 'Turno')
            ->where('target_id', $turno->id)
            ->where('action', 'turno.checkout_solicitado')
            ->orderByDesc('created_at')
            ->value('created_at')?->toIso8601String();
    }
}
