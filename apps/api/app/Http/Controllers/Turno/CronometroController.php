<?php

namespace App\Http\Controllers\Turno;

use App\Http\Controllers\Controller;
use App\Models\Turno;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-057 / ADR-017 (decisão a) — âncora do cronômetro bilateral (GET /api/turnos/{turno}/cronometro).
 *
 * O servidor é a ÚNICA fonte de verdade do tempo decorrido (CA-4): NÃO conta tiques nem mantém
 * estado de conexão. Devolve a âncora (`iniciado_em` = `check_in_at`, carimbado na transição
 * `aguardando_checkin → ativo`), o `encerrado_em` (`check_out_at`, na transição para finalizado) e a
 * sua própria hora (`servidor_agora`). Cada cliente calcula `offset = cliente_agora − servidor_agora`,
 * tica LOCALMENTE `decorrido = (cliente_agora − offset) − iniciado_em` e faz polling curto (~5s) só
 * para reconciliar o offset e detectar a saída de `ativo`. Dois clientes ancorados no MESMO
 * `iniciado_em` ficam sincronizados ≤ 2s por construção — sem WebSocket, sem SSE, sem infra nova
 * (fit com Cloud Run stateless, ADR-004).
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
            'encerrado_em' => $turno->check_out_at?->toIso8601String(),
            'servidor_agora' => now()->toIso8601String(),
        ]);
    }
}
