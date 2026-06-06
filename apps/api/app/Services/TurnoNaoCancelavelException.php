<?php

namespace App\Services;

use RuntimeException;

/**
 * STORY-066 (CA-2) — cancelamento pedido fora de `confirmado` (PDR-007: só antes do
 * check-in). Carrega o estado atual para o 422 da API ({ motivo: estado_invalido, estado })
 * — a UI recarrega a verdade ao fechar o dialog (SCREEN-066 §A.6).
 */
class TurnoNaoCancelavelException extends RuntimeException
{
    public function __construct(public readonly string $estado)
    {
        parent::__construct("Turno não cancelável no estado {$estado}");
    }
}
