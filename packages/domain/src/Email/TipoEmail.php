<?php

namespace Turni\Domain\Email;

/**
 * Tipos de e-mail transacional do MVP (ADR-011 §d).
 * O vocabulário é do domínio; o adapter (Resend) traduz para template/assunto/remetente.
 */
enum TipoEmail: string
{
    case AprovacaoConcedida = 'aprovacao_concedida';
    case LembreteCompletarCadastro = 'lembrete_completar_cadastro';
    case RecuperacaoSenha = 'recuperacao_senha';

    /** Assunto canônico fixado em ADR-011 §d (não reabrir — SCREEN-STORY-021 §5). */
    public function assunto(): string
    {
        return match ($this) {
            self::AprovacaoConcedida => 'Seu cadastro foi aprovado — acesse o Turni',
            self::LembreteCompletarCadastro => 'Complete seu cadastro no Turni',
            self::RecuperacaoSenha => 'Redefina sua senha no Turni',
        };
    }
}
