<?php

namespace App\Domain\Contratos;

use RuntimeException;

/** Nenhuma versão ativa do template aplicável — bloqueia a geração do aceite (estado inválido do sistema). */
class TemplateIndisponivelException extends RuntimeException
{
    public function __construct(string $slug)
    {
        parent::__construct("Sem versão ativa do template '{$slug}'.");
    }
}
