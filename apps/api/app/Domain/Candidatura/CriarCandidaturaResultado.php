<?php

namespace App\Domain\Candidatura;

use App\Models\Candidatura;

/**
 * STORY-050 — desfecho da tentativa de candidatura, traduzível direto para a resposta HTTP
 * pelo controller (CA-1):
 *  - `criada(...)`   → 201 com a candidatura (e flag `alerta` para MEI/PJ na habitualidade).
 *  - `bloqueada(...)`→ 422 (gate / vaga fechada) ou 409 (já candidatou), com `erro` + `mensagem`
 *                      + `detalhe?`. `mensagem` é a prosa exibida verbatim ao usuário (CA-9).
 */
final class CriarCandidaturaResultado
{
    /** @param array<string,mixed>|null $detalhe */
    private function __construct(
        public readonly ?Candidatura $candidatura,
        public readonly bool $alerta,
        public readonly ?string $erro,
        public readonly ?string $mensagem,
        public readonly ?array $detalhe,
        public readonly int $status,
    ) {}

    public static function criada(Candidatura $candidatura, bool $alerta): self
    {
        return new self($candidatura, $alerta, null, null, null, 201);
    }

    /** @param array<string,mixed>|null $detalhe */
    public static function bloqueada(string $erro, string $mensagem, ?array $detalhe, int $status): self
    {
        return new self(null, false, $erro, $mensagem, $detalhe, $status);
    }

    public function sucesso(): bool
    {
        return $this->candidatura !== null;
    }
}
