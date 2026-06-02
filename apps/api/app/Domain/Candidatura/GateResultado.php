<?php

namespace App\Domain\Candidatura;

/**
 * STORY-050 — resultado da verificação de um gate de candidatura. Value object imutável.
 *
 * Três desfechos:
 *  - `passou()`        → o gate não barra; segue para o próximo (ou cria a candidatura).
 *  - `bloqueio(...)`   → barra a candidatura; carrega o código de `erro` (estável, p/ a UI
 *                        mapear o título do modal), a `mensagem` em prosa (exibida verbatim no
 *                        client — CA-9) e um `detalhe` opcional (turno_id, conflito_com, ...).
 *  - `alerta(...)`     → NÃO barra (MEI/PJ na habitualidade — CA-4); a candidatura é criada,
 *                        mas o `detalhe` (`alerta=true`) viaja no payload p/ o painel do
 *                        contratante (STORY-051). É um "passou, mas anote isto".
 */
final class GateResultado
{
    /** @param array<string,mixed>|null $detalhe */
    private function __construct(
        public readonly bool $bloqueado,
        public readonly ?string $erro,
        public readonly ?string $mensagem,
        public readonly ?array $detalhe,
        public readonly bool $temAlerta,
    ) {}

    public static function passou(): self
    {
        return new self(false, null, null, null, false);
    }

    /** @param array<string,mixed>|null $detalhe */
    public static function bloqueio(string $erro, string $mensagem, ?array $detalhe = null): self
    {
        return new self(true, $erro, $mensagem, $detalhe, false);
    }

    /** Não bloqueia, mas anota um alerta no payload (habitualidade MEI/PJ — CA-4). */
    public static function alerta(string $motivo): self
    {
        return new self(false, null, null, ['alerta' => true, 'motivo' => $motivo], true);
    }
}
