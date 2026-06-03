<?php

namespace App\Console\Commands;

use App\Enums\NotificacaoTipo;
use App\Mail\NotificacaoMail;
use App\Models\Notificacao;
use App\Models\Template;
use App\Services\Notificacao\EmailTemplateRenderer;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use RuntimeException;
use Throwable;

/**
 * STORY-053 (CA-5) — worker de e-mail das notificações. Roda 1×/min (Schedule em
 * routes/console.php, reusa o Cloud Run Job + Scheduler de STORY-034).
 *
 * Drena a FILA IMPLÍCITA `enviada_email_em IS NULL AND falha_envio_em IS NULL` (scope
 * Notificacao::pendentesDeEmail): para cada pendente resolve o template ativo do tipo
 * (NotificacaoTipo::templateSlug), interpola corpo (EmailTemplateRenderer) + assunto
 * (assuntoEmail + payload) e envia via NotificacaoMail (mesmo provedor de STORY-021 — Resend em
 * homolog/prod, Mailpit em dev).
 *
 *  - sucesso       → `enviada_email_em = now()` (sai da fila);
 *  - falha         → `tentativas_envio++`; o espaçamento de ~1min entre execuções É o backoff;
 *  - 3ª falha      → `falha_envio_em = now()` + log ERROR `notificacao.email.falhou` (alerta).
 *
 * Logs mascaram o destinatário (ADR-008) — nunca PII em claro. Idempotente entre execuções
 * (withoutOverlapping é só higiene): uma já enviada/falhada não é re-selecionada.
 */
class EnviarEmailsNotificacaoCommand extends Command
{
    protected $signature = 'notificacoes:enviar-emails';

    protected $description = 'Envia os e-mails das notificações pendentes (fila implícita) — STORY-053 CA-5.';

    /** ADR-011 §g — 3 tentativas antes de marcar falha definitiva. */
    private const MAX_TENTATIVAS = 3;

    /** Teto por execução: protege a janela de 1min mesmo num pico de criação. */
    private const LOTE = 200;

    public function handle(EmailTemplateRenderer $renderer): int
    {
        $pendentes = Notificacao::query()
            ->pendentesDeEmail()
            ->with('destinatario')
            ->limit(self::LOTE)
            ->get();

        $enviadas = 0;
        $falhas = 0;

        foreach ($pendentes as $notificacao) {
            try {
                $this->enviarUma($notificacao, $renderer);
                $enviadas++;
            } catch (Throwable $e) {
                $this->registrarFalha($notificacao, $e);
                $falhas++;
            }
        }

        $this->info("Notificações: {$enviadas} enviadas, {$falhas} com falha nesta execução.");

        return self::SUCCESS;
    }

    private function enviarUma(Notificacao $notificacao, EmailTemplateRenderer $renderer): void
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
        $conteudo = $renderer->renderizar($versao->conteudo, $payload, $destinatario->name);

        $inicio = microtime(true);

        Mail::to($destinatario->email)->send(new NotificacaoMail(
            assunto: $this->assunto($tipo, $payload),
            conteudo: $conteudo,
        ));

        $notificacao->update(['enviada_email_em' => now()]);

        Log::info('notificacao.email.sent', [
            'event' => 'notificacao.email.sent',
            'tipo' => $tipo->value,
            'notificacao_id' => $notificacao->id,
            'destinatario' => $this->mascarar($destinatario->email),
            'latencia_ms' => (int) round((microtime(true) - $inicio) * 1000),
        ]);
    }

    /** Assunto canônico (NotificacaoTipo) com os `{snake_case}` do payload interpolados (ex.: {prazo_em}). */
    private function assunto(NotificacaoTipo $tipo, array $payload): string
    {
        $assunto = $tipo->assuntoEmail();

        return preg_replace_callback(
            '/\{([a-z0-9_]+)\}/',
            fn (array $m): string => isset($payload[$m[1]]) ? (string) $payload[$m[1]] : $m[0],
            $assunto,
        ) ?? $assunto;
    }

    private function registrarFalha(Notificacao $notificacao, Throwable $e): void
    {
        $tentativas = $notificacao->tentativas_envio + 1;
        $definitiva = $tentativas >= self::MAX_TENTATIVAS;

        $notificacao->update([
            'tentativas_envio' => $tentativas,
            'falha_envio_em' => $definitiva ? now() : null,
        ]);

        $mascarado = $notificacao->destinatario !== null ? $this->mascarar($notificacao->destinatario->email) : '—';

        Log::log($definitiva ? 'error' : 'warning', $definitiva ? 'notificacao.email.falhou' : 'notificacao.email.failed', [
            'event' => $definitiva ? 'notificacao.email.falhou' : 'notificacao.email.failed',
            'tipo' => $notificacao->tipo->value,
            'notificacao_id' => $notificacao->id,
            'destinatario' => $mascarado,
            'tentativas' => $tentativas,
            'definitiva' => $definitiva,
            'causa' => $e->getMessage(),
        ]);
    }

    /** E-mail mascarado para log (ADR-008) — primeira letra + domínio. */
    private function mascarar(string $email): string
    {
        [$local, $dominio] = array_pad(explode('@', $email, 2), 2, '');

        return $dominio === '' ? mb_substr($local, 0, 1).'•••' : mb_substr($local, 0, 1).'•••@'.$dominio;
    }
}
