<?php

namespace App\Domain\Aceites;

/** Usuário não está em `await_cadastro` (já ativo, ainda pendente, ou sem welcome). */
class FunilInvalidoException extends CompletarCadastroException
{
    public function __construct(public readonly string $estado)
    {
        parent::__construct("Completar cadastro indisponível para o estado de funil: {$estado}");
    }

    public function code(): string
    {
        return 'funil_invalido';
    }
}
