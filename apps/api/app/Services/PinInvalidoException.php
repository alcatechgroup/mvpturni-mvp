<?php

namespace App\Services;

/** 422 `pin_invalido` — sem expor tentativas restantes (CA-2: não dar pista a força bruta). */
class PinInvalidoException extends \DomainException
{
    public function __construct()
    {
        parent::__construct('PIN inválido.');
    }
}
