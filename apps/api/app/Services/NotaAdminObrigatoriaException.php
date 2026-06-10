<?php

namespace App\Services;

/**
 * STORY-093 / ADR-020 (Decisão 3, passo 1) — 422 `nota_admin_obrigatoria`: a resolução da disputa
 * exige a história da decisão na trilha (mesmo princípio do `PixFalhas`). A CA-3 da estória chamava
 * a nota de "opcional"; o conflito foi resolvido a favor do modelo do ADR (nota presente) — decisão
 * registrada nas Notas do agente da STORY-093.
 */
class NotaAdminObrigatoriaException extends \DomainException
{
    public function __construct()
    {
        parent::__construct('Resolução de disputa exige nota do admin não-vazia.');
    }
}
