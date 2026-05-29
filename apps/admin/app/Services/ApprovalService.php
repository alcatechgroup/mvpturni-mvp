<?php

namespace App\Services;

use App\Domain\Email\EmailTransacional;
use App\Domain\Email\TipoEmail;
use App\Exceptions\CadastroJaProcessadoException;
use App\Jobs\EnviarEmailTransacionalJob;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Núcleo da fila de aprovação (STORY-019). Encapsula as duas ações de admin sobre um
 * cadastro pendente — aprovar e remover — com transição de estado atômica, audit log
 * imutável (ADR-009), dispatch de e-mail (ADR-011) e proteção contra race condition.
 */
class ApprovalService
{
    public function __construct(
        private readonly AuditLogService $auditLog,
        private readonly Request $request,
    ) {}

    /**
     * Aprova um cadastro pendente: pendente_aprovacao → liberado.
     *
     * Race condition (CA-6): a transição é um UPDATE condicional atômico em `status`.
     * Se nenhuma linha for afetada (outro admin já processou), lança exceção sem
     * efeito colateral (sem audit log, sem e-mail).
     *
     * @throws CadastroJaProcessadoException
     */
    public function approve(User $target, User $actor): void
    {
        // Lock otimista via UPDATE condicional — só transiciona se ainda pendente.
        $afetadas = User::query()
            ->whereKey($target->getKey())
            ->where('status', 'pendente_aprovacao')
            ->update([
                'status' => 'liberado',
                'welcome_seen_at' => null,
                'cadastro_completed_at' => null,
            ]);

        if ($afetadas === 0) {
            throw new CadastroJaProcessadoException;
        }

        $target->refresh();

        $this->auditLog->log(
            action: 'admin.user.approved',
            actorId: $actor->getKey(),
            targetType: 'User',
            targetId: $target->getKey(),
            payload: [
                'role' => $target->role,
                'tipo_pessoa' => $this->tipoPessoaDe($target),
            ],
        );

        EnviarEmailTransacionalJob::dispatch(new EmailTransacional(
            destinatario: $target->email,
            tipo: TipoEmail::AprovacaoConcedida,
            dados: [
                'nome' => $target->name,
                'link_acesso' => config('app.webapp_url', config('app.url')),
            ],
        ));

        $this->logAcao('admin.user.approved', $actor, $target);
    }

    /**
     * Remove um cadastro pendente (recusa implícita — PDR-001).
     *
     * Estratégia ADR-009 §Consequências: soft-delete lógico via `status='recusado'`,
     * preservando o registro para o audit log referenciá-lo por `target_id`. Hard delete
     * (direito ao esquecimento) fica para o job de retenção, fora do MVP.
     *
     * Sem e-mail ao removido (PDR-001 — MVP). Sem motivo textual (PDR-001).
     *
     * @throws CadastroJaProcessadoException
     */
    public function remove(User $target, User $actor): void
    {
        $previousStatus = $target->status;

        $afetadas = User::query()
            ->whereKey($target->getKey())
            ->where('status', 'pendente_aprovacao')
            ->update(['status' => 'recusado']);

        if ($afetadas === 0) {
            throw new CadastroJaProcessadoException;
        }

        $this->auditLog->log(
            action: 'admin.user.removed',
            actorId: $actor->getKey(),
            targetType: 'User',
            targetId: $target->getKey(),
            payload: ['previous_status' => $previousStatus],
        );

        $this->logAcao('admin.user.removed', $actor, $target);
    }

    private function tipoPessoaDe(User $target): ?string
    {
        return $target->isProfissional()
            ? $target->profissionalProfile?->tipo_pessoa
            : null;
    }

    /** Log estruturado por ação do admin (ADR-008 / CA-14), com request_id. */
    private function logAcao(string $action, User $actor, User $target): void
    {
        Log::info($action, [
            'event' => $action,
            'service' => 'backoffice',
            'request_id' => $this->requestId(),
            'actor_user_id' => $actor->getKey(),
            'target_user_id' => $target->getKey(),
            'target_role' => $target->role,
        ]);
    }

    private function requestId(): string
    {
        $traceHeader = $this->request->header('X-Cloud-Trace-Context');

        return $traceHeader
            ? explode('/', $traceHeader)[0]
            : (string) Str::uuid();
    }
}
