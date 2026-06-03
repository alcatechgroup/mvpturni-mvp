<?php

namespace App\Services\Notificacao;

use App\Enums\NotificacaoTipo;
use App\Jobs\EnviarEmailDaNotificacaoJob;
use App\Models\AuditLog;
use App\Models\Notificacao;
use Illuminate\Http\Request;

/**
 * STORY-053 — ponto único de criação de notificação (CA-2/3/4 e os hooks dos templates 4/5).
 *
 * Idempotente pela `idempotency_key` (UNIQUE): o mesmo evento disparado 2x não gera 2 linhas
 * (story §"Idempotência"). Só na criação efetiva grava `notificacao.criada` em `audit_logs`
 * (trilha de domínio, ADR-013 Decisão 5 — distinta do admin_audit_log).
 */
class CriarNotificacaoService
{
    public function __construct(private readonly Request $request) {}

    /**
     * @param  array<string,mixed>  $payload
     */
    public function criar(
        NotificacaoTipo $tipo,
        int $destinatarioId,
        ?int $vagaId,
        ?int $candidaturaId,
        array $payload,
        string $idempotencyKey,
    ): Notificacao {
        $notificacao = Notificacao::firstOrCreate(
            ['idempotency_key' => $idempotencyKey],
            [
                'tipo' => $tipo,
                'destinatario_id' => $destinatarioId,
                'vaga_id' => $vagaId,
                'candidatura_id' => $candidaturaId,
                'payload' => $payload,
                'criada_em' => now(),
            ],
        );

        if ($notificacao->wasRecentlyCreated) {
            AuditLog::create([
                'actor_id' => $this->request->user()?->id,
                'action' => 'notificacao.criada',
                'target_type' => 'Notificacao',
                'target_id' => $notificacao->id,
                'payload' => [
                    'tipo' => $tipo->value,
                    'destinatario_id' => $destinatarioId,
                    'vaga_id' => $vagaId,
                ],
                'ip' => $this->request->ip(),
                'user_agent' => $this->request->userAgent(),
            ]);

            // CA-5 — entrega o e-mail pela fila (caminho que roda em homolog via queue:work).
            // Fila `database`: o job é INSERIDO na tabela `jobs` dentro da MESMA transação que cria a
            // notificação (e a candidatura/edição que a originou), então o worker só o enxerga após o
            // commit e o rollback o desfaz junto — transação-seguro sem precisar de afterCommit.
            EnviarEmailDaNotificacaoJob::dispatch($notificacao->id);
        }

        return $notificacao;
    }
}
