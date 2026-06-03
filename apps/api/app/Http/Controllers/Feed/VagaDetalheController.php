<?php

namespace App\Http\Controllers\Feed;

use App\Domain\Avaliacao\AvaliacoesPendentesProfissional;
use App\Domain\Vaga\EdicaoMaterial;
use App\Domain\Vaga\VagaDetalhe;
use App\Domain\Vaga\VagaDetalheQuery;
use App\Enums\CandidaturaEstado;
use App\Http\Controllers\Controller;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
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

    public function show(Request $request, string $vaga, AvaliacoesPendentesProfissional $gate): JsonResponse
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
                // `id` (STORY-050): o client precisa dele para a retirada (DELETE /candidaturas/{id}).
                'id' => $candidatura->id,
                'estado' => $candidatura->estado->value,
                'criada_em' => $candidatura->created_at?->toIso8601String(),
            ],
            // STORY-052 CA-11 — quando a candidatura está em revisão pós-edição, o banner do
            // profissional precisa do prazo + do que mudou (diff "o que viu → estado atual").
            'revisao' => $this->revisao($d),
            'motivo_bloqueio' => $motivoBloqueio,
        ];
    }

    /**
     * STORY-052 CA-11 — bloco de revisão pós-edição (null se a candidatura não está em
     * `pendente_revisao_apos_edicao`). O diff compara a versão que o profissional viu/aceitou
     * (`vaga_versoes` apontada pela candidatura) contra o estado material atual da vaga; a
     * comparação é a mesma do contratante (EdicaoMaterial), garantindo simetria (SCREEN-052).
     *
     * @return array{prazo_em:?string,diff:list<array<string,mixed>>}|null
     */
    private function revisao(VagaDetalhe $d): ?array
    {
        $candidatura = $d->candidatura;
        if ($candidatura === null || $candidatura->estado !== CandidaturaEstado::PendenteRevisaoAposEdicao) {
            return null;
        }

        $snapshot = $candidatura->vagaVersao?->snapshot;
        $diff = $snapshot === null
            ? []
            : $this->resolverFuncoes(
                EdicaoMaterial::diff(
                    EdicaoMaterial::snapshotDePayload($snapshot),
                    EdicaoMaterial::snapshotDeVaga($d->vaga),
                ),
            );

        return [
            'prazo_em' => $candidatura->revisao_prazo_em?->toIso8601String(),
            'diff' => $diff,
        ];
    }

    /**
     * Substitui os ids de função por nomes legíveis nas linhas de diff do tipo `funcao` — o
     * banner mostra "Garçom → Cozinheiro", não ids. Demais linhas passam intactas.
     *
     * @param  list<array<string,mixed>>  $diff
     * @return list<array<string,mixed>>
     */
    private function resolverFuncoes(array $diff): array
    {
        $ids = [];
        foreach ($diff as $linha) {
            if (($linha['tipo'] ?? null) === 'funcao') {
                $ids[] = $linha['antes'];
                $ids[] = $linha['depois'];
            }
        }
        if ($ids === []) {
            return $diff;
        }

        $nomes = Funcao::query()->whereIn('id', array_filter($ids))->pluck('nome', 'id');

        return array_map(function (array $linha) use ($nomes) {
            if (($linha['tipo'] ?? null) === 'funcao') {
                $linha['antes'] = $nomes[$linha['antes']] ?? null;
                $linha['depois'] = $nomes[$linha['depois']] ?? null;
            }

            return $linha;
        }, $diff);
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
