<?php

namespace Turni\Domain\Email;

/**
 * Value Object de e-mail transacional (ADR-011 §b).
 * Contrato de `dados` por tipo está em ADR-011 §d:
 *  - aprovacao_concedida: {nome, link_acesso}
 *  - lembrete_completar_cadastro: {nome, link_completar, horas_pendente}
 *  - recuperacao_senha: {nome, link_redefinicao, expiracao_minutos}
 */
final readonly class EmailTransacional
{
    public function __construct(
        public string $destinatario,
        public TipoEmail $tipo,
        public array $dados = [],
        /**
         * Chave de idempotência (CA-14). Quando presente, dois despachos com a mesma
         * chave não geram dois envios (ver EnviarEmailTransacionalJob::uniqueId).
         * Convenção: "<tipo>:<user_id>" — decisão do chamador.
         */
        public ?string $idempotencyKey = null,
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

    /** Nome do destinatário com fallback (SCREEN-STORY-021 §5 — saudação "Olá." sem nome). */
    public function nome(): ?string
    {
        $nome = trim((string) ($this->dados['nome'] ?? ''));

        return $nome === '' ? null : $nome;
    }
}
