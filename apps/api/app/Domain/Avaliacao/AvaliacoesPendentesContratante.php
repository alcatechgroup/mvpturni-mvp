<?php

namespace App\Domain\Avaliacao;

use App\Models\User;

/**
 * STORY-046 CA-5 / PDR-005 — fonte do gate de publicação do contratante.
 *
 * Stub-honesto (decisão do PO, 2026-06-02): turnos e avaliações são do EPIC-003 e ainda
 * não existem no schema. Sem turnos finalizados, não há avaliação pendente — o gate
 * nunca dispara em produção ainda, mas o contrato fica pronto e a UI é testada com
 * pending>0 mockado no front. Quando o EPIC-003 entrar, esta classe passa a contar os
 * turnos finalizados do contratante sem avaliação recíproca registrada.
 */
class AvaliacoesPendentesContratante
{
    /** @return array{pending:int, turnos:list<array<string,mixed>>} */
    public function para(User $contratante): array
    {
        return ['pending' => 0, 'turnos' => []];
    }
}
