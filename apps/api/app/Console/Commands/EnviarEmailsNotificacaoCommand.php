<?php

namespace App\Console\Commands;

use App\Models\Notificacao;
use App\Services\Notificacao\EnvioEmailNotificacao;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * STORY-053 (CA-5) — sweeper manual/backfill da fila implícita de e-mail das notificações.
 *
 * NÃO é o caminho primário de entrega: o e-mail de cada notificação é enviado por
 * EnviarEmailDaNotificacaoJob (despachado na criação, processado pelo `queue:work` que roda em
 * homolog/prod). Este comando é a rede de segurança — reenvia o que sobrou em
 * `enviada_email_em IS NULL AND falha_envio_em IS NULL` (scope pendentesDeEmail): útil para backfill
 * manual ou caso o `schedule:run` venha a existir em homolog (hoje não roda — por isso a entrega
 * primária é via fila, não via Schedule).
 *
 *  - sucesso  → `enviada_email_em` (sai da fila);
 *  - falha    → `tentativas_envio++`; 3ª → `falha_envio_em` + log ERROR `notificacao.email.falhou`.
 *
 * Reusa EnvioEmailNotificacao (mesmo render+envio do Job). Idempotente: já enviada/falhada não é
 * re-selecionada.
 */
class EnviarEmailsNotificacaoCommand extends Command
{
    protected $signature = 'notificacoes:enviar-emails';

    protected $description = 'Sweeper/backfill: reenvia e-mails de notificações pendentes na fila implícita — STORY-053 CA-5.';

    /** ADR-011 §g — 3 tentativas antes de marcar falha definitiva. */
    private const MAX_TENTATIVAS = 3;

    /** Teto por execução: protege a janela mesmo num pico de criação. */
    private const LOTE = 200;

    public function handle(EnvioEmailNotificacao $envio): int
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
                $envio->enviar($notificacao);
                $enviadas++;
            } catch (Throwable $e) {
                $this->registrarFalha($notificacao, $e);
                $falhas++;
            }
        }

        $this->info("Notificações: {$enviadas} enviadas, {$falhas} com falha nesta execução.");

        return self::SUCCESS;
    }

    private function registrarFalha(Notificacao $notificacao, Throwable $e): void
    {
        $tentativas = $notificacao->tentativas_envio + 1;
        $definitiva = $tentativas >= self::MAX_TENTATIVAS;

        $notificacao->update([
            'tentativas_envio' => $tentativas,
            'falha_envio_em' => $definitiva ? now() : null,
        ]);

        Log::log($definitiva ? 'error' : 'warning', $definitiva ? 'notificacao.email.falhou' : 'notificacao.email.failed', [
            'event' => $definitiva ? 'notificacao.email.falhou' : 'notificacao.email.failed',
            'tipo' => $notificacao->tipo->value,
            'notificacao_id' => $notificacao->id,
            'tentativas' => $tentativas,
            'definitiva' => $definitiva,
            'causa' => $e->getMessage(),
        ]);
    }
}
