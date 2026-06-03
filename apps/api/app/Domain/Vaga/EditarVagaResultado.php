<?php

namespace App\Domain\Vaga;

use App\Models\Vaga;

/**
 * STORY-052 — desfecho de uma edição de vaga (EditarVagaService). Carrega o que o controller
 * precisa para o contrato da resposta (CA-1): a vaga atualizada, se foi material, o diff e
 * quais candidaturas foram notificadas (movidas para `pendente_revisao_apos_edicao`).
 */
final class EditarVagaResultado
{
    /**
     * @param  list<array{campo:string,label:string,tipo:string,antes:mixed,depois:mixed}>  $diff
     * @param  list<int>  $candidatosNotificadosIds
     */
    public function __construct(
        public readonly Vaga $vaga,
        public readonly bool $material,
        public readonly array $diff,
        public readonly array $candidatosNotificadosIds,
    ) {}
}
