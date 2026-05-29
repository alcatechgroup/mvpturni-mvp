<?php

namespace App\Domain\Email;

/**
 * Anti-Corruption Layer de e-mail transacional (ADR-011 §b).
 *
 * O domínio fala seu vocabulário (TipoEmail::AprovacaoConcedida); o adapter concreto
 * traduz para o SDK do provedor. Nenhuma camada acima do adapter conhece o Resend.
 *
 * STORY-019 fornece um adapter log-only (placeholder). STORY-021 implementa o adapter
 * Resend + Mailables e troca o binding no container — sem tocar o chamador.
 */
interface EnviaEmailTransacional
{
    public function enviar(EmailTransacional $email): void;
}
