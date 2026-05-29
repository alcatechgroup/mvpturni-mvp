<?php

namespace App\Domain\Email;

/**
 * Value Object de e-mail transacional (ADR-011 §b).
 * Contrato de `dados` por tipo está em ADR-011 §d — para aprovacao_concedida: {nome, link_acesso}.
 */
final readonly class EmailTransacional
{
    public function __construct(
        public string $destinatario,
        public TipoEmail $tipo,
        public array $dados = [],
    ) {}

    /** E-mail mascarado para log estruturado (ADR-008 — nunca expor PII em log claro). */
    public function destinatarioMascarado(): string
    {
        [$local, $dominio] = array_pad(explode('@', $this->destinatario, 2), 2, '');

        $prefixo = mb_substr($local, 0, 1);

        return $dominio === ''
            ? $prefixo.'•••'
            : $prefixo.'•••@'.$dominio;
    }
}
