<?php

namespace App\Domain\Avaliacao;

use App\Models\User;

/**
 * STORY-048 CA-8 / PDR-005 — fonte do gate de candidatura do profissional.
 *
 * Stub-honesto (mesma decisão de AvaliacoesPendentesContratante, STORY-046): turnos e
 * avaliações são do EPIC-003 e ainda não existem no schema. Sem turno finalizado por
 * avaliar, `pode_candidatar` é sempre true — o gate nunca dispara em produção ainda, mas o
 * contrato fica pronto e a UI do gate (botão desabilitado + tooltip) é testada com
 * `podeCandidatar=false` mockado. Quando o EPIC-003 entrar, esta classe passa a checar se o
 * profissional tem turno finalizado sem avaliação registrada (PDR-005: gate bloqueia AÇÃO,
 * não VISIBILIDADE — o feed continua visível).
 */
class AvaliacoesPendentesProfissional
{
    public function podeCandidatar(User $profissional): bool
    {
        return true;
    }
}
