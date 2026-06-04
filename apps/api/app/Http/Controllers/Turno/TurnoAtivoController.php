<?php

namespace App\Http\Controllers\Turno;

use App\Enums\TurnoStatus;
use App\Http\Controllers\Controller;
use App\Models\Turno;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-057 / ADR-017 — turno `ativo` do usuário logado (GET /api/turnos/meu-ativo). Atalho de
 * NAVEGAÇÃO para a PoC do cronômetro: o WebApp instalado (PWA standalone) não tem barra de URL, e
 * a home (feed/minhas-vagas) não lista turnos — então sem este endpoint o usuário não chega ao
 * cronômetro sem digitar a URL. Devolve `{ turno_id }` (ou null) do turno em andamento, olhando os
 * DOIS lados (profissional e contratante). É a semente de "Meus turnos" (STORY-059).
 */
class TurnoAtivoController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();

        $turno = Turno::query()
            ->where('status', TurnoStatus::Ativo)
            ->where(fn ($q) => $q
                ->where('profissional_id', $user->id)
                ->orWhere('contratante_id', $user->id))
            ->latest('check_in_at')
            ->first();

        return response()->json(['turno_id' => $turno?->id]);
    }
}
