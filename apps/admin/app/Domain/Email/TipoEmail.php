<?php

namespace App\Domain\Email;

/**
 * Tipos de e-mail transacional do MVP (ADR-011 §d).
 * O vocabulário é do domínio; o adapter (STORY-021) traduz para template/assunto do Resend.
 */
enum TipoEmail: string
{
    case AprovacaoConcedida = 'aprovacao_concedida';
    case LembreteCompletarCadastro = 'lembrete_completar_cadastro';
    case RecuperacaoSenha = 'recuperacao_senha';
}
