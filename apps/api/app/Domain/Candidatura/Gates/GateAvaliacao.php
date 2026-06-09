<?php

namespace App\Domain\Candidatura\Gates;

use App\Domain\Avaliacao\AvaliacoesPendentesProfissional;
use App\Domain\Candidatura\GateResultado;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * STORY-050 Gate 1 (CA-2) / STORY-086 (ADR-019 D5) — PDR-005: avaliação bloqueante. Se o
 * profissional tem turno finalizado pendente de avaliação, não pode se candidatar — precisa
 * avaliar antes.
 *
 * Reusa o mesmo julgamento do feed/detalhe (AvaliacoesPendentesProfissional, STORY-048), agora
 * ligado à pendência real derivada do estado (ADR-019 D2). O `detalhe.turno_id` carrega o turno
 * por avaliar **mais antigo**, que guia o client à tela de avaliação (deep-link — STORY-087/088).
 *
 * Fail-secure (F2): qualquer erro ao consultar a pendência **bloqueia** a candidatura — o
 * caminho de "não tenho certeza" nunca libera a ação (com `turno_id` null, sem deep-link).
 */
final class GateAvaliacao
{
    public function __construct(private readonly AvaliacoesPendentesProfissional $avaliacoes) {}

    public function verificar(User $profissional, Vaga $vaga): GateResultado
    {
        try {
            $turno = $this->avaliacoes->turnoPendente($profissional);
        } catch (Throwable $e) {
            Log::warning('gate_avaliacao.consulta_falhou', [
                'papel' => 'profissional',
                'user_id' => $profissional->id,
                'erro' => $e->getMessage(),
            ]);

            // Fail-secure: na dúvida, bloqueia — sem turno_id (o client cai no fluxo genérico).
            return GateResultado::bloqueio(
                'gate_avaliacao',
                'Avalie seu último turno para se candidatar.',
                ['turno_id' => null],
            );
        }

        if ($turno === null) {
            return GateResultado::passou();
        }

        return GateResultado::bloqueio(
            'gate_avaliacao',
            'Avalie seu último turno para se candidatar.',
            ['turno_id' => $turno->id],
        );
    }
}
