<?php

// STORY-019 — núcleo da fila de aprovação: transição, audit log, dispatch, race condition.

use App\Exceptions\CadastroJaProcessadoException;
use App\Models\AdminAuditLog;
use App\Models\ProfissionalProfile;
use App\Models\User;
use App\Services\ApprovalService;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Turni\Domain\Email\EnviarEmailTransacionalJob;
use Turni\Domain\Email\TipoEmail;

uses(RefreshDatabase::class);

function approvalService(): ApprovalService
{
    return app(ApprovalService::class);
}

// ──────────────────────────────────────────────────────────────
// Aprovar — caminho feliz
// ──────────────────────────────────────────────────────────────

test('aprovar transiciona pendente_aprovacao para liberado', function () {
    Queue::fake();
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->profissional()->create();

    approvalService()->approve($alvo, $admin);

    expect($alvo->fresh()->status)->toBe('liberado')
        ->and($alvo->fresh()->welcome_seen_at)->toBeNull()
        ->and($alvo->fresh()->cadastro_completed_at)->toBeNull();
});

test('aprovar grava admin.user.approved no audit log com role e tipo_pessoa', function () {
    Queue::fake();
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->profissional()->create();
    ProfissionalProfile::factory()->for($alvo)->tipo('MEI')->create();

    approvalService()->approve($alvo->fresh(), $admin);

    $log = AdminAuditLog::where('action', 'admin.user.approved')->sole();
    expect($log->actor_id)->toBe($admin->id)
        ->and($log->target_type)->toBe('User')
        ->and($log->target_id)->toBe($alvo->id)
        ->and($log->payload['role'])->toBe('profissional')
        ->and($log->payload['tipo_pessoa'])->toBe('MEI');
});

test('aprovar enfileira e-mail aprovacao_concedida na fila database', function () {
    Queue::fake();
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->profissional()->create(['email' => 'novo@exemplo.com']);

    approvalService()->approve($alvo, $admin);

    Queue::assertPushed(EnviarEmailTransacionalJob::class, function ($job) {
        return $job->email->tipo === TipoEmail::AprovacaoConcedida
            && $job->email->destinatario === 'novo@exemplo.com'
            && $job->connection === 'database';
    });
});

test('aprovar contratante grava tipo_pessoa nulo no audit log', function () {
    Queue::fake();
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->contratante()->create();

    approvalService()->approve($alvo, $admin);

    $log = AdminAuditLog::where('action', 'admin.user.approved')->sole();
    expect($log->payload['tipo_pessoa'])->toBeNull();
});

// ──────────────────────────────────────────────────────────────
// Aprovar — race condition (CA-6)
// ──────────────────────────────────────────────────────────────

test('aprovar cadastro que já não está pendente lança exceção sem efeito colateral', function () {
    Queue::fake();
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->profissional()->create();

    // Outro admin já aprovou (simulação): status não é mais pendente.
    $alvo->update(['status' => 'liberado']);

    expect(fn () => approvalService()->approve($alvo, $admin))
        ->toThrow(CadastroJaProcessadoException::class);

    // Fail-secure: nenhum audit log, nenhum e-mail.
    expect(AdminAuditLog::where('action', 'admin.user.approved')->count())->toBe(0);
    Queue::assertNothingPushed();
});

// ──────────────────────────────────────────────────────────────
// Remover (CA-8) — soft-delete via status=recusado (ADR-009)
// ──────────────────────────────────────────────────────────────

test('remover marca status recusado e preserva o registro', function () {
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->profissional()->create();

    approvalService()->remove($alvo, $admin);

    expect(User::find($alvo->id))->not->toBeNull()
        ->and($alvo->fresh()->status)->toBe('recusado');
});

test('remover grava admin.user.removed com previous_status', function () {
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->contratante()->create();

    approvalService()->remove($alvo, $admin);

    $log = AdminAuditLog::where('action', 'admin.user.removed')->sole();
    expect($log->target_id)->toBe($alvo->id)
        ->and($log->payload['previous_status'])->toBe('pendente_aprovacao');
});

test('remover não envia e-mail ao removido (PDR-001)', function () {
    Queue::fake();
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->profissional()->create();

    approvalService()->remove($alvo, $admin);

    Queue::assertNothingPushed();
});

test('remover cadastro que já não está pendente lança exceção', function () {
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->profissional()->create(['status' => 'liberado']);

    expect(fn () => approvalService()->remove($alvo, $admin))
        ->toThrow(CadastroJaProcessadoException::class);

    expect(AdminAuditLog::where('action', 'admin.user.removed')->count())->toBe(0);
});

// ──────────────────────────────────────────────────────────────
// Imutabilidade do audit log (CA-9)
// ──────────────────────────────────────────────────────────────

test('audit log é imutável — UPDATE lança exceção de banco', function () {
    Queue::fake();
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->profissional()->create();
    approvalService()->approve($alvo, $admin);

    $log = AdminAuditLog::where('action', 'admin.user.approved')->sole();

    expect(fn () => DB::statement('UPDATE admin_audit_log SET action = ? WHERE id = ?', ['hacked', $log->id]))
        ->toThrow(QueryException::class);
});
