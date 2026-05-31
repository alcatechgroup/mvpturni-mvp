<?php

namespace App\Domain\Aceites;

/** Não há versão ativa do template aplicável (falha de seed/config — não deveria ocorrer em homolog). */
class TemplateIndisponivelException extends CompletarCadastroException
{
    public function __construct(public readonly string $slug)
    {
        parent::__construct("Sem versão ativa para o template: {$slug}");
    }

    public function code(): string
    {
        return 'template_indisponivel';
    }
}
