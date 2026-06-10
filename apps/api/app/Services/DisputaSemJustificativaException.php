<?php

namespace App\Services;

/**
 * STORY-092 / ADR-020 (Decisão 2) — 422 `justificativa_obrigatoria`: não existe disputa sem
 * justificativa (`domain/disputa.md`). Sem ela o caminho do contratante é validar o check-out.
 */
class DisputaSemJustificativaException extends \DomainException
{
    public function __construct()
    {
        parent::__construct('Disputa exige justificativa do contratante não-vazia.');
    }
}
