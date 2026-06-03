<?php

namespace App\Domain\Feed;

use App\Domain\Match\MatchScoring;
use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Models\Candidatura;
use App\Models\ProfissionalProfile;
use App\Models\User;
use App\Models\Vaga;
use App\Support\Geo\Haversine;
use App\Support\Telemetry\MatchEvents;
use App\Support\Telemetry\MotivoFiltro;
use Illuminate\Support\Collection;

/**
 * STORY-048 (CA-1..CA-5, CA-7, CA-9) — feed do profissional. Junta a camada de query
 * (ADR-013: índice idx_vagas_feed + prefiltro bbox do raio) com o cálculo de match
 * on-demand (ADR-014: função pura, sem cache). Fluxo:
 *
 *   1. Visibilidade (SQL): estado `aberta`, função primária OU secundária do profissional,
 *      data futura, e — quando há geo — bounding-box do raio. Cap de 100 candidatos.
 *   2. Distância precisa (PHP): Haversine refina o bbox e descarta o que cai fora do raio.
 *   3. Match (PHP): MatchScoring.paraEntidades — score total + componentes + breakdown.
 *   4. Ranqueamento (PHP): score DESC, boost de plano DESC (stub null), data_inicio ASC.
 *   5. Paginação page-based (page size 20) sobre o conjunto ranqueado.
 *
 * O score NÃO é calculado em SQL (ADR-014): por isso o ranqueamento e a paginação rodam em
 * memória sobre o conjunto candidato já capado em 100 — barato no volume do MVP.
 */
final class FeedQuery
{
    /** Cap do conjunto candidato antes de pontuar (ADR-013/ADR-014). */
    public const CAP = 100;

    /** Tamanho de página (CA-10). */
    public const PER_PAGE = 20;

    /** 1 grau de latitude ≈ 111.32 km (aprox. esférica suficiente para bbox de raio). */
    private const KM_POR_GRAU = 111.32;

    public function __construct(
        private readonly MatchScoring $scoring = new MatchScoring,
    ) {}

    public function paraProfissional(User $profissional, FeedFiltro $filtro, int $page): FeedResultado
    {
        $page = max(1, $page);
        $perfil = $profissional->profissionalProfile;

        // Sem perfil ou sem função primária não há critério de visibilidade — feed vazio.
        if ($perfil === null || $perfil->funcao_id === null) {
            return new FeedResultado([], $page, false);
        }

        $candidatos = $this->candidatos($profissional, $perfil, $filtro);
        // Estado da candidatura ativa por vaga (uma consulta): deriva `ja_candidatou` e, quando
        // `pendente_revisao_apos_edicao`, o selo "Vaga editada" do card (STORY-052 CA-11).
        $estadoPorVaga = $this->estadoCandidaturaPorVaga($profissional, $candidatos->pluck('id')->all());

        $feedVagas = [];
        foreach ($candidatos as $vaga) {
            $distancia = $this->distanciaKm($perfil, $vaga);

            // Refino preciso do raio (o bbox é só aproximação grosseira): fora do raio sai
            // da visibilidade e dispara telemetria (CA-7).
            if ($this->foraDoRaio($perfil, $distancia)) {
                MatchEvents::vagaFiltrada($vaga->id, $profissional->id, MotivoFiltro::ForaRaio);

                continue;
            }

            $score = $this->scoring->paraEntidades($perfil, $vaga, $distancia);

            // "Alto match" é filtro do usuário (pós-cálculo), não um descarte de
            // visibilidade — por isso não dispara feed.vaga_filtrada.
            if ($filtro === FeedFiltro::AltoMatch && $score->total < 80) {
                continue;
            }

            $estado = $estadoPorVaga[$vaga->id] ?? null;
            $feedVagas[] = new FeedVaga(
                vaga: $vaga,
                distanciaKm: $distancia,
                score: $score,
                jaCandidatou: $estado !== null,
                emRevisao: $estado === CandidaturaEstado::PendenteRevisaoAposEdicao,
            );
        }

        $feedVagas = $this->ranquear($feedVagas);

        return $this->paginar($feedVagas, $page, $profissional->id);
    }

    /**
     * Conjunto candidato pela camada de query (ADR-013). Visibilidade dura em SQL; o raio
     * fino e o score ficam para o PHP. Cap de 100, ordenado por data (índice idx_vagas_feed).
     *
     * @return Collection<int, Vaga>
     */
    private function candidatos(User $profissional, ProfissionalProfile $perfil, FeedFiltro $filtro): Collection
    {
        $funcoes = $this->funcoesVisiveis($perfil, $filtro);
        if ($funcoes === []) {
            return collect();
        }

        $query = Vaga::query()
            ->where('estado', VagaEstado::Aberta)
            ->whereIn('funcao_id', $funcoes)
            ->where('data_inicio', '>', now())
            ->with('funcao:id,nome');

        // Prefiltro bounding-box do raio (só quando o profissional tem geo declarada).
        if ($this->temGeo($perfil)) {
            [$latMin, $latMax, $lngMin, $lngMax] = $this->boundingBox($perfil);
            $query->whereBetween('lat', [$latMin, $latMax])
                ->whereBetween('lng', [$lngMin, $lngMax]);
        }

        // "Candidatadas": só vagas com candidatura ativa deste profissional (CA-4).
        if ($filtro === FeedFiltro::Candidatadas) {
            $query->whereHas('candidaturas', fn ($q) => $q
                ->where('profissional_id', $profissional->id)
                ->whereIn('estado', $this->estadosCandidaturaAtiva()));
        }

        return $query
            ->orderBy('data_inicio')
            ->limit(self::CAP)
            ->get();
    }

    /**
     * Funções que entram na visibilidade: "Minha função" usa só a primária; os demais
     * filtros usam primária + secundárias (domain/vaga.md §Visibilidade).
     *
     * @return list<int>
     */
    private function funcoesVisiveis(ProfissionalProfile $perfil, FeedFiltro $filtro): array
    {
        $primaria = (int) $perfil->funcao_id;
        if ($filtro === FeedFiltro::MinhaFuncao) {
            return [$primaria];
        }

        $secundarias = array_map('intval', $perfil->funcoes_secundarias ?? []);

        return array_values(array_unique([$primaria, ...$secundarias]));
    }

    /**
     * Estado da candidatura ATIVA do profissional por vaga (dentre as candidatas). Alimenta
     * `ja_candidatou` (CA-1) e o selo de revisão do card (STORY-052 CA-11). Uma só consulta.
     *
     * @param  list<int>  $vagaIds
     * @return array<int,CandidaturaEstado>
     */
    private function estadoCandidaturaPorVaga(User $profissional, array $vagaIds): array
    {
        if ($vagaIds === []) {
            return [];
        }

        return Candidatura::query()
            ->where('profissional_id', $profissional->id)
            ->whereIn('vaga_id', $vagaIds)
            ->whereIn('estado', $this->estadosCandidaturaAtiva())
            ->pluck('estado', 'vaga_id')
            ->mapWithKeys(fn ($estado, $vagaId) => [(int) $vagaId => $estado])
            ->all();
    }

    /** @return list<CandidaturaEstado> */
    private function estadosCandidaturaAtiva(): array
    {
        return [CandidaturaEstado::Pendente, CandidaturaEstado::PendenteRevisaoAposEdicao];
    }

    private function temGeo(ProfissionalProfile $perfil): bool
    {
        return $perfil->lat !== null
            && $perfil->lng !== null
            && (int) ($perfil->raio_max_km ?? 0) > 0;
    }

    /**
     * Distância Haversine em km entre profissional e vaga; null se faltar geo de qualquer
     * lado (componente de distância então zera no match — ADR-014). A fórmula vive em
     * App\Support\Geo\Haversine (STORY-049): o detalhe da vaga reusa a mesma distância.
     */
    private function distanciaKm(ProfissionalProfile $perfil, Vaga $vaga): ?float
    {
        return Haversine::km(
            $perfil->lat !== null ? (float) $perfil->lat : null,
            $perfil->lng !== null ? (float) $perfil->lng : null,
            $vaga->lat !== null ? (float) $vaga->lat : null,
            $vaga->lng !== null ? (float) $vaga->lng : null,
        );
    }

    private function foraDoRaio(ProfissionalProfile $perfil, ?float $distancia): bool
    {
        // Sem geo do profissional não há filtro de raio — o feed não fica vazio por falta
        // de coordenada (SCREEN-048 §4.9 / premissa de back).
        if (! $this->temGeo($perfil) || $distancia === null) {
            return false;
        }

        return $distancia > (float) $perfil->raio_max_km;
    }

    /** Caixa lat/lng que contém o círculo do raio (prefiltro grosseiro do bbox). */
    private function boundingBox(ProfissionalProfile $perfil): array
    {
        $lat = (float) $perfil->lat;
        $lng = (float) $perfil->lng;
        $raio = (float) $perfil->raio_max_km;

        $dLat = $raio / self::KM_POR_GRAU;
        // O comprimento de 1 grau de longitude encolhe com o cosseno da latitude.
        $cos = max(0.01, cos(deg2rad($lat)));
        $dLng = $raio / (self::KM_POR_GRAU * $cos);

        return [$lat - $dLat, $lat + $dLat, $lng - $dLng, $lng + $dLng];
    }

    /**
     * Ranqueamento (CA-3): score DESC, boost de plano DESC, data_inicio ASC. O boost é
     * stub null (ADR-014 Decisão 3) — sem plano modelado, todos empatam em 0 e a ordem cai
     * para score e data. Mantemos o critério explícito para quando o plano existir.
     *
     * @param  list<FeedVaga>  $feedVagas
     * @return list<FeedVaga>
     */
    private function ranquear(array $feedVagas): array
    {
        usort($feedVagas, function (FeedVaga $a, FeedVaga $b) {
            return $b->score->total <=> $a->score->total
                ?: $this->boostPlano($b->vaga) <=> $this->boostPlano($a->vaga)
                ?: $a->vaga->data_inicio <=> $b->vaga->data_inicio;
        });

        return $feedVagas;
    }

    /** Boost de plano do contratante — stub (ADR-014 Decisão 3): sem plano modelado = 0. */
    private function boostPlano(Vaga $vaga): int
    {
        return 0;
    }

    /**
     * Recorta a página e dispara a telemetria de apresentação (CA-7) só para as vagas
     * efetivamente retornadas no response.
     *
     * @param  list<FeedVaga>  $feedVagas
     */
    private function paginar(array $feedVagas, int $page, int $profissionalId): FeedResultado
    {
        $total = count($feedVagas);
        $offset = ($page - 1) * self::PER_PAGE;
        $pagina = array_slice($feedVagas, $offset, self::PER_PAGE);
        $hasNext = $total > $offset + self::PER_PAGE;

        foreach ($pagina as $fv) {
            MatchEvents::vagaApresentada($fv->vaga->id, $profissionalId, $fv->score);
        }

        return new FeedResultado(array_values($pagina), $page, $hasNext);
    }
}
