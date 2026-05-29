<?php

namespace App\Services;

use App\Domain\Templates\TemplateContentValidator;
use App\Exceptions\PlaceholderInvalidoException;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use InvalidArgumentException;

/**
 * STORY-020 / ADR-010 / PDR-012 — Núcleo do versionamento de templates contratuais.
 *
 * Duas operações de admin, ambas auditáveis (ADR-009):
 *   - criarVersao(): cria uma nova versão (ativa=false) a partir de conteúdo editado;
 *   - ativar(): transação atômica que troca qual versão está ativa.
 *
 * A versão ativa é imutável in-place (PDR-012): toda mudança de conteúdo é nova versão —
 * garantido também por trigger no banco. Aceites já firmados apontam para a versão original.
 */
class TemplateService
{
    public function __construct(
        private readonly AuditLogService $auditLog,
        private readonly TemplateContentValidator $validator,
        private readonly Request $request,
    ) {}

    /**
     * Cria a próxima versão (sequencial) de um template, como rascunho (ativa=false).
     *
     * @throws InvalidArgumentException conteúdo vazio
     * @throws PlaceholderInvalidoException placeholder fora da lista canônica (CA-5)
     */
    public function criarVersao(Template $template, string $conteudo, User $admin): TemplateVersao
    {
        $conteudo = trim($conteudo);

        if ($conteudo === '') {
            throw new InvalidArgumentException('O conteúdo não pode ficar vazio.');
        }

        $desconhecidos = $this->validator->placeholdersDesconhecidos($conteudo);
        if ($desconhecidos !== []) {
            throw new PlaceholderInvalidoException($desconhecidos);
        }

        return DB::transaction(function () use ($template, $conteudo, $admin) {
            // Sequência por template; o UNIQUE(template_id, versao) protege contra corrida.
            $proxima = ((int) $template->versoes()->max('versao')) + 1;

            $versao = TemplateVersao::create([
                'template_id' => $template->id,
                'versao' => $proxima,
                'conteudo' => $conteudo,
                'criado_por_admin_id' => $admin->id,
                'ativa' => false,
            ]);

            $this->auditLog->log(
                action: 'admin.template.version_created',
                actorId: $admin->id,
                targetType: 'TemplateVersao',
                targetId: $versao->id,
                payload: ['template_slug' => $template->slug, 'versao' => $versao->versao],
            );

            $this->logEstruturado('admin.template.version_created', $admin, $template, $versao);

            return $versao;
        });
    }

    /**
     * Ativa uma versão (atômico — CA-9). Desativa a ativa atual e ativa a alvo na mesma
     * transação. Atende também a "voltar para versão anterior" (CA-11), pois funciona com
     * qualquer versão do template. No-op silencioso se a versão já estiver ativa.
     */
    public function ativar(TemplateVersao $versao, User $admin): void
    {
        if ($versao->ativa) {
            return;
        }

        DB::transaction(function () use ($versao, $admin) {
            // Desativa a ativa atual (se houver). O estado intermediário "zero ativas" é
            // permitido pelo partial unique index (proíbe >1, não proíbe 0).
            TemplateVersao::query()
                ->where('template_id', $versao->template_id)
                ->where('ativa', true)
                ->update(['ativa' => false]);

            TemplateVersao::query()
                ->whereKey($versao->id)
                ->update(['ativa' => true]);

            $this->auditLog->log(
                action: 'admin.template.version_activated',
                actorId: $admin->id,
                targetType: 'TemplateVersao',
                targetId: $versao->id,
                payload: ['template_slug' => $versao->template->slug, 'versao' => $versao->versao],
            );

            $this->logEstruturado('admin.template.version_activated', $admin, $versao->template, $versao);
        });

        $versao->refresh();
    }

    /** Log estruturado por ação (ADR-008 / observabilidade), com request_id. */
    private function logEstruturado(string $action, User $admin, Template $template, TemplateVersao $versao): void
    {
        Log::info($action, [
            'event' => $action,
            'service' => 'backoffice',
            'request_id' => $this->requestId(),
            'actor_user_id' => $admin->id,
            'template_slug' => $template->slug,
            'template_versao' => $versao->versao,
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
