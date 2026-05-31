<?php

namespace App\Domain\Aceites;

/** Documento (CPF/CNPJ) já cadastrado por outro profissional (CA-3) — erro genérico ao cliente. */
class DocumentoDuplicadoException extends CompletarCadastroException
{
    public function code(): string
    {
        return 'documento_duplicado';
    }
}
