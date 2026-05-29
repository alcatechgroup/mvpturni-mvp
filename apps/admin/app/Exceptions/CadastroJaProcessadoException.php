<?php

namespace App\Exceptions;

use RuntimeException;

/**
 * Levantada quando um admin tenta aprovar/remover um cadastro que já não está em
 * `pendente_aprovacao` — tipicamente porque outro admin agiu em outra aba (CA-6).
 * Fail-secure: nenhuma transição parcial ocorre.
 */
class CadastroJaProcessadoException extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('Este cadastro já foi processado por outro admin.');
    }
}
