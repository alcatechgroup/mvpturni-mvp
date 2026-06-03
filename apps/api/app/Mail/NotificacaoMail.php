<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Address;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

/**
 * STORY-053 (CA-5) — Mailable dos e-mails de notificação. Paralelo ao TransacionalMail (STORY-021),
 * mas o conteúdo NÃO é fixo em código: vem pronto do EmailTemplateRenderer (corpo editável no
 * Backoffice + payload da notificação). Reusa as mesmas views/layout
 * (`emails.transacional` / `emails.transacional-text`) → paridade HTML/text e visual idêntico aos
 * e-mails transacionais. Assunto já interpolado pelo worker; remetente de config('mail.from').
 */
class NotificacaoMail extends Mailable
{
    use Queueable, SerializesModels;

    /** @param array<string,mixed> $conteudo array consumido por emails.transacional* */
    public function __construct(
        public readonly string $assunto,
        public readonly array $conteudo,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(
            from: new Address(
                (string) config('mail.from.address'),
                (string) config('mail.from.name'),
            ),
            subject: $this->assunto,
        );
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.transacional',
            text: 'emails.transacional-text',
            with: $this->conteudo,
        );
    }
}
