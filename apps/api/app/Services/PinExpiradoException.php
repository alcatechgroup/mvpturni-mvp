<?php

namespace App\Services;

/** 422 `pin_expirado` — 3 erros invalidaram o PIN; o turno voltou a `confirmado` (CA-3). */
class PinExpiradoException extends \DomainException
{
    public function __construct()
    {
        parent::__construct('PIN expirado por excesso de tentativas.');
    }
}
