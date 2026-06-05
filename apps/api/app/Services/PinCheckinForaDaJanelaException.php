<?php

namespace App\Services;

/** 422 `fora_da_janela` — carrega a janela para a UI explicar (SCREEN-061 §4.2/4.3). */
class PinCheckinForaDaJanelaException extends \DomainException
{
    public function __construct(public readonly string $abreEm, public readonly string $fechaEm)
    {
        parent::__construct('Fora da janela de geração do PIN de check-in.');
    }
}
