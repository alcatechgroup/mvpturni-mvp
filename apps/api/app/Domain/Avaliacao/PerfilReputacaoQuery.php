<?php

namespace App\Domain\Avaliacao;

use App\Enums\NivelProfissional;
use App\Models\Avaliacao;
use App\Models\ContratanteProfile;
use App\Models\User;

/**
 * STORY-085 / ADR-019 + DDR-004 (CA-6) — monta a reputação consultável do perfil.
 *
 * Reciprocidade: profissional expõe score/nível/turnos (+ XP atual e XP até o próximo nível
 * SÓ para o próprio dono — niveis-e-score.md: XP é privado do profissional); contratante expõe
 * só score. Depoimentos = avaliações recebidas com comentário não-vazio, mais recentes 1º,
 * limitadas a 3 (DDR-004).
 *
 * Assimetria de autor (DDR-004, LGPD): depoimento SOBRE O PROFISSIONAL traz o estabelecimento
 * (nominal); depoimento SOBRE O CONTRATANTE NÃO traz o nome do profissional (anônimo) — o
 * contrato de leitura do contratante jamais trafega identidade individual do profissional.
 */
class PerfilReputacaoQuery
{
    /** DDR-004 — até 3 depoimentos mais recentes na visão expandida. */
    private const LIMITE_DEPOIMENTOS = 3;

    /** DDR-004 — selo "Novo" enquanto houver menos de 3 avaliações recebidas. */
    private const MIN_AVALIACOES_ESTABELECIDO = 3;

    /** @return array<string,mixed> */
    public function para(User $alvo, bool $ehDono): array
    {
        if ($alvo->isProfissional()) {
            return $this->perfilProfissional($alvo, $ehDono);
        }

        // Contratante (ou qualquer outro papel com profile de contratante).
        return $this->perfilContratante($alvo);
    }

    /** @return array<string,mixed> */
    private function perfilProfissional(User $pro, bool $ehDono): array
    {
        $profile = $pro->profissionalProfile;
        abort_if($profile === null, 404, 'Perfil de profissional não encontrado.');

        $total = $this->totalAvaliacoes($pro);

        $payload = [
            'papel' => 'profissional',
            'score' => $this->score1Casa($profile->score),
            'nivel' => $profile->nivel,
            'turnos_realizados' => (int) $profile->turnos_realizados,
            'total_avaliacoes' => $total,
            'selo_novo' => $total < self::MIN_AVALIACOES_ESTABELECIDO,
            'depoimentos' => $this->depoimentos($pro, nominal: true),
        ];

        // XP é visível só para o próprio profissional (niveis-e-score.md §Visibilidade).
        if ($ehDono) {
            $xp = (int) $profile->xp;
            $payload['xp'] = $xp;
            $payload['xp_proximo_nivel'] = NivelProfissional::xpAteProximoNivel($xp);
        }

        return $payload;
    }

    /** @return array<string,mixed> */
    private function perfilContratante(User $contratante): array
    {
        $profile = $contratante->contratanteProfile;
        abort_if($profile === null, 404, 'Perfil de contratante não encontrado.');

        $total = $this->totalAvaliacoes($contratante);

        return [
            'papel' => 'contratante',
            'score' => $this->score1Casa($profile->score),
            'total_avaliacoes' => $total,
            'selo_novo' => $total < self::MIN_AVALIACOES_ESTABELECIDO,
            // Anônimo: depoimento sobre o contratante não traz o nome do profissional (LGPD).
            'depoimentos' => $this->depoimentos($contratante, nominal: false),
        ];
    }

    private function totalAvaliacoes(User $avaliado): int
    {
        return Avaliacao::query()->where('avaliado_id', $avaliado->id)->count();
    }

    /**
     * Depoimentos = avaliações recebidas com comentário não-vazio, mais recentes 1º (até 3).
     * `nominal` decide se o autor é identificado (estabelecimento) ou anônimo (LGPD).
     *
     * @return list<array<string,mixed>>
     */
    private function depoimentos(User $avaliado, bool $nominal): array
    {
        return Avaliacao::query()
            ->where('avaliado_id', $avaliado->id)
            ->whereNotNull('comentario')
            ->where('comentario', '<>', '')
            ->orderByDesc('created_at')
            ->limit(self::LIMITE_DEPOIMENTOS)
            ->get()
            ->map(fn (Avaliacao $a) => [
                'estrelas' => $a->estrelas,
                'comentario' => $a->comentario,
                'autor_nome' => $nominal ? $this->nomeEstabelecimento($a->autor_id) : null,
                'data' => $a->created_at?->toIso8601String(),
            ])
            ->all();
    }

    /** Nome do estabelecimento autor (apelido > nome > name) — DDR-004 nominal. */
    private function nomeEstabelecimento(string $autorId): ?string
    {
        $profile = ContratanteProfile::query()->with('user')->where('user_id', $autorId)->first();

        return $profile?->apelido_estabelecimento
            ?: $profile?->nome_estabelecimento
            ?: $profile?->user?->name;
    }

    /** Score exibido com 1 casa decimal (niveis-e-score.md — ex. 4.9). */
    private function score1Casa(mixed $score): float
    {
        return round((float) $score, 1);
    }
}
