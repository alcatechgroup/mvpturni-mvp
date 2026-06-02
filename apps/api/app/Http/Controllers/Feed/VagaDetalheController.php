<?php

namespace App\Http\Controllers\Feed;

use App\Domain\Avaliacao\AvaliacoesPendentesProfissional;
use App\Domain\Vaga\VagaDetalhe;
use App\Domain\Vaga\VagaDetalheQuery;
use App\Http\Controllers\Controller;
use App\Models\ContratanteProfile;
use App\Models\Vaga;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-049 — detalhe da vaga + breakdown explicável (GET /api/vagas/{vaga}/detalhe).
 * RBAC (CA-7): só `profissional` (status=ativo garantido pelo FunnelGuard na rota);
 * contratante → 403. Vaga inexistente/encerrada/no passado → 404 (SCREEN-049 §4.7). O
 * cálculo de match e a visibilidade ficam no VagaDetalheQuery (ADR-014); aqui só RBAC, gate
 * PDR-005, motivo de bloqueio e serialização do contrato (CA-1).
 */
class VagaDetalheController extends Controller
{
    public function __construct(private readonly VagaDetalheQuery $query) {}

    public function show(Request $request, int $vaga, AvaliacoesPendentesProfissional $gate): JsonResponse
    {
        $user = $request->user();
        abort_unless($user !== null && $user->isProfissional(), 403);

        $detalhe = $this->query->paraProfissional($user, $vaga);
        abort_if($detalhe === null, 404);

        // Gate PDR-005 (CA-5): a candidatura é bloqueada (não a visibilidade). `motivo_bloqueio`
        // só vem preenchido quando o profissional NÃO pode candidatar. Conflito de horário e
        // habitualidade são slots do contrato com lógica em STORY-050.
        $podeCandidatar = $gate->podeCandidatar($user);
        $motivoBloqueio = $podeCandidatar ? null : 'Avalie seu último turno para se candidatar.';

        return response()->json($this->serializar($detalhe, $podeCandidatar, $motivoBloqueio));
    }

    /** @return array<string,mixed> */
    private function serializar(VagaDetalhe $d, bool $podeCandidatar, ?string $motivoBloqueio): array
    {
        $vaga = $d->vaga;
        $candidatura = $d->candidatura;

        return [
            'id' => $vaga->id,
            'funcao' => $vaga->funcao?->nome,
            'estabelecimento' => $this->estabelecimento($vaga),
            'cidade' => $vaga->cidade,
            'data_inicio' => $vaga->data_inicio->toIso8601String(),
            'data_fim' => $vaga->data_fim->toIso8601String(),
            'valor' => (float) $vaga->valor,
            'distancia_km' => $d->distanciaKm !== null ? round($d->distanciaKm, 1) : null,
            'score_breakdown' => $d->score->toArray(),
            'pode_candidatar' => $podeCandidatar,
            'ja_candidatou' => $d->jaCandidatou(),
            'candidatura' => $candidatura === null ? null : [
                'estado' => $candidatura->estado->value,
                'criada_em' => $candidatura->created_at?->toIso8601String(),
            ],
            'motivo_bloqueio' => $motivoBloqueio,
        ];
    }

    /**
     * Nome curto do estabelecimento para o cabeçalho (SCREEN-049 §3): apelido quando houver,
     * senão o nome do estabelecimento; null se o contratante não tiver perfil.
     */
    private function estabelecimento(Vaga $vaga): ?string
    {
        /** @var ContratanteProfile|null $perfil */
        $perfil = $vaga->contratante?->contratanteProfile;

        return $perfil?->apelido_estabelecimento ?: $perfil?->nome_estabelecimento;
    }
}
