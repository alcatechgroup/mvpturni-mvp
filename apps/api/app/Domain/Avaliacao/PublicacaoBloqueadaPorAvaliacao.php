<?php

namespace App\Domain\Avaliacao;

use DomainException;

/**
 * STORY-086 / ADR-019 D5 / PDR-005 — gate bloqueante do contratante. Lançada por
 * PublicarVagaService quando há turno finalizado pendente de avaliação: a publicação de nova
 * vaga é barrada até o contratante avaliar. Carrega o `turnoId` mais antigo por avaliar (ou
 * null no caminho fail-secure) para o deep-link da tela de avaliação. O VagaController traduz
 * para 422 com `erro=gate_avaliacao` (mesma forma do gate de candidatura).
 */
final class PublicacaoBloqueadaPorAvaliacao extends DomainException
{
    public function __construct(public readonly ?string $turnoId)
    {
        parent::__construct('Avalie seu último turno para publicar uma nova vaga.');
    }
}
