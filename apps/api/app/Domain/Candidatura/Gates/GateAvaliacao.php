<?php

namespace App\Domain\Candidatura\Gates;

use App\Domain\Avaliacao\AvaliacoesPendentesProfissional;
use App\Domain\Candidatura\GateResultado;
use App\Models\User;
use App\Models\Vaga;

/**
 * STORY-050 Gate 1 (CA-2) — PDR-005: avaliação bloqueante. Se o profissional tem turno
 * finalizado pendente de avaliação, não pode se candidatar — precisa avaliar antes.
 *
 * Reusa o mesmo julgamento do feed/detalhe (AvaliacoesPendentesProfissional, STORY-048),
 * que hoje é stub-honesto (sem turnos/avaliações no schema → sempre `true`). Quando o
 * EPIC-003 entrar, aquela classe passa a olhar turnos reais e o `detalhe.turno_id` guiará o
 * client para a tela de avaliação. Aqui o slot do contrato já existe (`turno_id` = null no MVP).
 */
final class GateAvaliacao
{
    public function __construct(private readonly AvaliacoesPendentesProfissional $avaliacoes) {}

    public function verificar(User $profissional, Vaga $vaga): GateResultado
    {
        if ($this->avaliacoes->podeCandidatar($profissional)) {
            return GateResultado::passou();
        }

        return GateResultado::bloqueio(
            'gate_avaliacao',
            'Avalie seu último turno para se candidatar.',
            // Slot do contrato (CA-2): o id do turno por avaliar guiará o deep-link quando o
            // EPIC-003 existir. O stub atual não expõe o turno, então fica null.
            ['turno_id' => null],
        );
    }
}
