<?php

namespace App\Events;

use App\Models\Vaga;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * STORY-052 (CA-3) — evento de domínio disparado quando o contratante faz uma edição
 * **material** (PDR-009) numa vaga que tem candidatos pendentes. STORY-053 consome este evento
 * para notificar cada candidato pendente (in-app + e-mail) com o diff do que mudou e o prazo de
 * revisão. O disparo carrega tudo que o consumidor precisa sem reconsultar o banco:
 *
 * - `$vaga` — a vaga já com os novos valores;
 * - `$diff` — lista ordenada de mudanças `[{campo,label,tipo,antes,depois}]` (EdicaoMaterial::diff);
 * - `$candidatosNotificadosIds` — ids das candidaturas movidas para `pendente_revisao_apos_edicao`.
 */
class VagaEditadaMaterialmente
{
    use Dispatchable;
    use SerializesModels;

    /**
     * @param  list<array{campo:string,label:string,tipo:string,antes:mixed,depois:mixed}>  $diff
     * @param  list<int>  $candidatosNotificadosIds
     */
    public function __construct(
        public readonly Vaga $vaga,
        public readonly array $diff,
        public readonly array $candidatosNotificadosIds,
    ) {}
}
