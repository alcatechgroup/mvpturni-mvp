<?php

namespace App\Http\Controllers\Turno;

use App\Http\Controllers\Controller;
use App\Models\Turno;
use App\Support\Geo\Geofencing;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-057 / ADR-017 (decisão b) — PoC do geofencing de check-in
 * (POST /api/turnos/{turno}/checkin-geo). Recebe a posição capturada pelo navegador
 * (`navigator.geolocation` no Flutter Web) e calcula a distância em metros até o estabelecimento
 * com `Support\Geo\Geofencing` (que reusa `Haversine` da STORY-049), gravando o snapshot
 * `geofencing_check_in = { ok, distancia_metros, capturado_em, razao? }` (PDR-008, alerta-e-registra).
 *
 * É a semente da STORY-061 (geração do PIN de check-in com geofencing). Aqui, como PoC, só prova o
 * caminho posição-do-navegador → backend → distância em metros; a geração do PIN e as transições
 * de estado vivem na STORY-061/062. RBAC: só o profissional do turno (é quem faz o check-in).
 * Falha de captura no cliente (permissão negada/timeout) chega com `lat/lng` nulos + `razao` e vira
 * `ok:false`, `distancia_metros:null` — nunca bloqueia.
 */
class CheckinGeoController extends Controller
{
    public function store(Request $request, Turno $turno): JsonResponse
    {
        $user = $request->user();
        abort_unless($user !== null && $user->id === $turno->profissional_id, 404);

        $dados = $request->validate([
            'lat' => ['nullable', 'numeric', 'between:-90,90'],
            'lng' => ['nullable', 'numeric', 'between:-180,180'],
            'razao' => ['nullable', 'string', 'in:permissao_negada,timeout,indisponivel'],
        ]);

        $vaga = $turno->vaga; // lat/lng do estabelecimento = snapshot da vaga (ADR-013).

        $resultado = Geofencing::avaliar(
            isset($dados['lat']) ? (float) $dados['lat'] : null,
            isset($dados['lng']) ? (float) $dados['lng'] : null,
            $vaga?->lat !== null ? (float) $vaga->lat : null,
            $vaga?->lng !== null ? (float) $vaga->lng : null,
            razaoSemCoordenada: $dados['razao'] ?? null,
        );

        $snapshot = [...$resultado, 'capturado_em' => now()->toIso8601String()];

        // Persiste o snapshot (status inalterado — o trigger de transição passa livre). É a forma
        // exata que a STORY-061 vai gravar; aqui torna a PoC observável na trilha de auditoria.
        $turno->geofencing_check_in = $snapshot;
        $turno->save();

        return response()->json($snapshot);
    }
}
