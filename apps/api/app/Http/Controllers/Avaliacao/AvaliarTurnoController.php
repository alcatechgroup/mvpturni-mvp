<?php

namespace App\Http\Controllers\Avaliacao;

use App\Domain\Avaliacao\Exceptions\AvaliacaoJaRegistradaException;
use App\Domain\Avaliacao\Exceptions\NaoParticipanteDoTurnoException;
use App\Domain\Avaliacao\Exceptions\TurnoNaoAvaliavelException;
use App\Domain\Avaliacao\RegistrarAvaliacaoService;
use App\Http\Controllers\Controller;
use App\Models\Turno;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-085 / ADR-019 (CA-3) — POST /api/turnos/{turno}/avaliar.
 *
 * Avaliação recíproca: o autenticado (profissional OU contratante do turno) avalia o outro
 * lado com estrelas obrigatórias (1–5) + comentário opcional. RBAC fail-secure: a direção e o
 * avaliado derivam do papel do autor no turno; não-participante → 403 (no service). Estado
 * inválido → 422; reenvio na mesma direção → 409.
 */
class AvaliarTurnoController extends Controller
{
    public function __construct(private readonly RegistrarAvaliacaoService $service) {}

    public function store(Request $request, Turno $turno): JsonResponse
    {
        $dados = $request->validate([
            'estrelas' => ['required', 'integer', 'between:1,5'],
            'comentario' => ['nullable', 'string', 'max:1000'],
        ]);

        try {
            $avaliacao = $this->service->registrar(
                $turno,
                $request->user(),
                (int) $dados['estrelas'],
                $dados['comentario'] ?? null,
            );
        } catch (NaoParticipanteDoTurnoException) {
            abort(403, 'Apenas quem participou do turno pode avaliá-lo.');
        } catch (TurnoNaoAvaliavelException $e) {
            return response()->json(['motivo' => 'estado_invalido', 'estado' => $e->estado], 422);
        } catch (AvaliacaoJaRegistradaException) {
            return response()->json(['motivo' => 'ja_avaliado'], 409);
        }

        return response()->json([
            'id' => $avaliacao->id,
            'direcao' => $avaliacao->direcao->value,
            'estrelas' => $avaliacao->estrelas,
            'comentario' => $avaliacao->comentario,
        ], 201);
    }
}
