<?php

namespace App\Domain\Avaliacao;

use App\Domain\Avaliacao\Exceptions\AvaliacaoJaRegistradaException;
use App\Domain\Avaliacao\Exceptions\NaoParticipanteDoTurnoException;
use App\Domain\Avaliacao\Exceptions\TurnoNaoAvaliavelException;
use App\Enums\AvaliacaoDirecao;
use App\Enums\TurnoStatus;
use App\Events\AvaliacaoRegistrada;
use App\Models\Avaliacao;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;

/**
 * STORY-085 / ADR-019 (CA-3) — registra a avaliação recíproca de um turno avaliável.
 *
 * Deriva direção + avaliado do papel do AUTOR no turno (fail-secure: quem não participou não
 * avalia). Valida o estado (só finalizado/finalizado_ajustado) e a unicidade por direção
 * (uma por direção/turno — UNIQUE no banco é a rede final; o pré-check dá erro amigável e a
 * corrida concorrente cai na UniqueConstraintViolationException → mesmo erro de produto).
 *
 * Insere a linha e dispara `AvaliacaoRegistrada` DENTRO da transação (ADR-019 Decisão 3): o
 * MotorReputacao roda síncrono e a reputação commita junto com a avaliação — ou nada.
 */
class RegistrarAvaliacaoService
{
    private const ESTADOS_AVALIAVEIS = [TurnoStatus::Finalizado, TurnoStatus::FinalizadoAjustado];

    /**
     * @throws TurnoNaoAvaliavelException|NaoParticipanteDoTurnoException|AvaliacaoJaRegistradaException
     */
    public function registrar(Turno $turno, User $autor, int $estrelas, ?string $comentario): Avaliacao
    {
        if (! in_array($turno->status, self::ESTADOS_AVALIAVEIS, true)) {
            throw new TurnoNaoAvaliavelException($turno->status->value);
        }

        [$direcao, $avaliadoId] = $this->direcaoEAvaliado($turno, $autor);

        if ($this->jaAvaliado($turno, $direcao)) {
            throw new AvaliacaoJaRegistradaException;
        }

        $comentario = $this->normalizarComentario($comentario);

        try {
            return DB::transaction(function () use ($turno, $autor, $avaliadoId, $direcao, $estrelas, $comentario) {
                $avaliacao = Avaliacao::create([
                    'turno_id' => $turno->id,
                    'autor_id' => $autor->id,
                    'avaliado_id' => $avaliadoId,
                    'direcao' => $direcao,
                    'estrelas' => $estrelas,
                    'comentario' => $comentario,
                ]);

                // Síncrono na transação — o motor recomputa a reputação do avaliado (ADR-019 D3/D4).
                AvaliacaoRegistrada::dispatch($avaliacao->id, $avaliadoId, $turno->id);

                return $avaliacao;
            });
        } catch (UniqueConstraintViolationException) {
            // Corrida: duas submissões na mesma direção — a 2ª bate no UNIQUE (rede final).
            throw new AvaliacaoJaRegistradaException;
        }
    }

    /**
     * Direção + avaliado a partir do papel do autor no turno. Quem não é o profissional nem o
     * contratante do turno não pode avaliar (RBAC fail-secure).
     *
     * @return array{0: AvaliacaoDirecao, 1: string}
     *
     * @throws NaoParticipanteDoTurnoException
     */
    private function direcaoEAvaliado(Turno $turno, User $autor): array
    {
        if ($autor->id === $turno->contratante_id) {
            return [AvaliacaoDirecao::ContratanteParaProfissional, $turno->profissional_id];
        }

        if ($autor->id === $turno->profissional_id) {
            return [AvaliacaoDirecao::ProfissionalParaContratante, $turno->contratante_id];
        }

        throw new NaoParticipanteDoTurnoException;
    }

    private function jaAvaliado(Turno $turno, AvaliacaoDirecao $direcao): bool
    {
        return Avaliacao::query()
            ->where('turno_id', $turno->id)
            ->where('direcao', $direcao)
            ->exists();
    }

    /** Comentário em branco vira null — só comentário não-vazio é depoimento (niveis-e-score.md). */
    private function normalizarComentario(?string $comentario): ?string
    {
        $comentario = $comentario !== null ? trim($comentario) : null;

        return $comentario === '' ? null : $comentario;
    }
}
