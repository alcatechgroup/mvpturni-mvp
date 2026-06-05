<?php

namespace App\Services;

/** 422 `estado_invalido` — turno fora do estado que a operação de PIN exige (061/062/064). */
class PinCheckinEstadoInvalidoException extends \DomainException
{
    public function __construct(public readonly string $estado)
    {
        parent::__construct("Turno em `{$estado}` não permite esta operação de PIN.");
    }
}
