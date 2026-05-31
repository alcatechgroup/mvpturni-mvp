<?php

namespace App\Domain\Aceites;

use RuntimeException;

/** Base das falhas de domínio do completar-cadastro (mapeadas para HTTP no controller). */
abstract class CompletarCadastroException extends RuntimeException
{
    /** Código estável consumido pelo cliente para mensageria. */
    abstract public function code(): string;
}
