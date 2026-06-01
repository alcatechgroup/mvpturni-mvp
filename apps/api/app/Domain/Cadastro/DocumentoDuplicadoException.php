<?php

namespace App\Domain\Cadastro;

use RuntimeException;

/** CA-3 — Documento já cadastrado por outro usuário. Mapeado a erro genérico no controller. */
class DocumentoDuplicadoException extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Documento já cadastrado.');
    }
}
