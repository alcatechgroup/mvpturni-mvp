<?php

namespace App\Services\Notificacao;

use App\Enums\NotificacaoTipo;
use App\Mail\NotificacaoMail;
use App\Models\Notificacao;
use App\Models\Template;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use RuntimeException;

/**
 * STORY-053 (CA-5) — núcleo de envio do e-mail de UMA notificação: resolve o template ativo do
 * tipo, interpola corpo (EmailTemplateRenderer) + assunto canônico, envia via NotificacaoMail e
 * marca `enviada_email_em`. Lança em qualquer falha (o chamador decide o retry/bookkeeping).
 *
 * Ponto único de envio, compartilhado por:
 *  - EnviarEmailDaNotificacaoJob (caminho PRIMÁRIO — roda no `queue:work` que existe em homolog/prod);
 *  - EnviarEmailsNotificacaoCommand (sweeper manual/backfill da fila implícita).
 */
class EnvioEmailNotificacao
{
    public function __construct(private readonly EmailTemplateRenderer $renderer) {}

    /**
     * @throws RuntimeException|TemplateEmailIncompletoException
     */
    public function enviar(Notificacao $notificacao): void
    {
        $destinatario = $notificacao->destinatario;
        if ($destinatario === null) {
            throw new RuntimeException("Notificação {$notificacao->id} sem destinatário.");
        }

        $tipo = $notificacao->tipo;
        $versao = Template::query()
            ->where('slug', $tipo->templateSlug())
            ->with('versaoAtiva')
            ->first()?->versaoAtiva;

        if ($versao === null) {
            throw new RuntimeException("Sem template de e-mail ativo para {$tipo->value}.");
        }

        $payload = $notificacao->payload ?? [];
        $conteudo = $this->renderer->renderizar($versao->conteudo, $payload, $destinatario->name);

        $inicio = microtime(true);

        $enviado = Mail::to($destinatario->email)->send(new NotificacaoMail(
            assunto: $this->assunto($tipo, $payload),
            conteudo: $conteudo,
        ));

        $notificacao->update(['enviada_email_em' => now()]);

        Log::info('notificacao.email.sent', [
            'event' => 'notificacao.email.sent',
            'tipo' => $tipo->value,
            'notificacao_id' => $notificacao->id,
            'destinatario' => $this->mascarar($destinatario->email),
            'message_id' => $enviado?->getMessageId(),
            'latencia_ms' => (int) round((microtime(true) - $inicio) * 1000),
        ]);
    }

    /** Assunto canônico (NotificacaoTipo) com os `{snake_case}` do payload interpolados (ex.: {prazo_em}). */
    public function assunto(NotificacaoTipo $tipo, array $payload): string
    {
        $assunto = $tipo->assuntoEmail();

        return preg_replace_callback(
            '/\{([a-z0-9_]+)\}/',
            fn (array $m): string => isset($payload[$m[1]]) ? (string) $payload[$m[1]] : $m[0],
            $assunto,
        ) ?? $assunto;
    }

    /** E-mail mascarado para log (ADR-008) — primeira letra + domínio. */
    public function mascarar(string $email): string
    {
        [$local, $dominio] = array_pad(explode('@', $email, 2), 2, '');

        return $dominio === '' ? mb_substr($local, 0, 1).'•••' : mb_substr($local, 0, 1).'•••@'.$dominio;
    }
}
