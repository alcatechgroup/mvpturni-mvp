<?php

namespace App\Domain\Turno;

use App\Models\Turno;

/**
 * STORY-058 — desfecho da aprovação de candidatura (vocabulário do contrato HTTP da
 * SCREEN-058 §10): aprovada (201 + turno), já aprovada (409 idempotente + turno_id) ou
 * bloqueada (422 + código/mensagem — habitualidade PDR-002, vaga fechada, estado inválido).
 */
final readonly class AprovarCandidaturaResultado
{
    private function __construct(
        public ?Turno $turno,
        public ?string $turnoIdExistente,
        public ?string $erro,
        public ?string $mensagem,
    ) {}

    public static function aprovada(Turno $turno): self
    {
        return new self($turno, null, null, null);
    }

    public static function jaAprovada(string $turnoId): self
    {
        return new self(null, $turnoId, 'ja_aprovada', null);
    }

    public static function bloqueada(string $erro, string $mensagem): self
    {
        return new self(null, null, $erro, $mensagem);
    }
}
