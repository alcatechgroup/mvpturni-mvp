<?php

// STORY-093 / ADR-020 (Decisão 3A) — POST /api/internal/turnos/{turno}/resolver-disputa.
// O comando do ADMIN "pagar integral": para um turno em `em_disputa`, grava a resolução na
// trilha (`turnos.disputa`), transita `em_disputa → finalizado` e RE-EMITE o MESMO evento do
// check-out feliz (TurnoFinalizado) — que já dispara captura padrão + Pix (TurnoFinalizadoListener
// → CapturarEPagarTurnoJob), a notificação ao profissional (NotificarTurnoFinalizado) e o gate de
// avaliação recíproca (NotificarAvaliacaoPendente). Nenhum caminho financeiro novo (F1): a captura
// é single-sourced na api. Canal admin→api: segredo service-to-service (X-Internal-Token) — o admin
// é processo separado e NÃO consegue emitir o evento in-process (IDR-032). RBAC fail-secure: o
// admin_id asserido tem de ser isAdmin().

use App\Enums\NotificacaoTipo;
use App\Enums\TurnoStatus;
use App\Events\TurnoFinalizado;
use App\Jobs\CapturarEPagarTurnoJob;
use App\Models\AuditLog;
use App\Models\Notificacao;
use App\Models\Turno;
use App\Models\User;
use App\Services\NotaAdminObrigatoriaException;
use App\Services\PinCheckinEstadoInvalidoException;
use App\Services\ResolverDisputaService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Queue;
use Illuminate\Testing\TestResponse;

uses(RefreshDatabase::class);

/** Turno em `em_disputa` com a disputa jsonb já aberta (estado herdado da STORY-092). */
function turnoParaResolver(array $disputaExtra = [], array $attrs = []): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::EmDisputa)->create(array_merge([
        'valor' => 200.00, 'taxa_turni' => 30.00, 'total_contratante' => 230.00,
    ], $attrs));

    $turno->forceFill(['disputa' => array_merge([
        'aberta_em' => now()->subMinutes(8)->toIso8601String(),
        'aberta_por' => $turno->contratante_id,
        'justificativa_contratante' => 'O profissional saiu 40 min antes do fim combinado.',
        'resolucao' => null,
        'nota_admin' => null,
        'resolvida_em' => null,
        'resolvida_por' => null,
    ], $disputaExtra)])->save();

    return $turno->fresh(['profissional', 'contratante']);
}

function tokenInterno(): string
{
    return (string) config('services.internal.token');
}

function resolverDisputa(Turno $turno, ?User $admin, array $body = [], ?string $token = null): TestResponse
{
    $payload = array_merge(['nota_admin' => 'Verifiquei o chat e o geofencing: serviço prestado, pago integral.'], $body);
    if ($admin !== null) {
        $payload['admin_id'] ??= $admin->id;
    }

    $headers = [];
    $token ??= tokenInterno();
    if ($token !== '') {
        $headers['X-Internal-Token'] = $token;
    }

    return test()->postJson("/api/internal/turnos/{$turno->id}/resolver-disputa", $payload, $headers);
}

// ── CA-1/CA-3 — resolução feliz: trilha + transição + evento reusado ───────────

test('CA-1/CA-3: admin paga integral → 200 finalizado, disputa resolvida na trilha e audit', function () {
    Event::fake([TurnoFinalizado::class]);
    $admin = User::factory()->admin()->ativo()->create();
    $turno = turnoParaResolver();

    resolverDisputa($turno, $admin, ['nota_admin' => 'Serviço prestado conforme combinado.'])
        ->assertStatus(200)
        ->assertJsonPath('estado', 'finalizado');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::Finalizado)
        ->and($turno->disputa['resolucao'])->toBe('paga_integral')
        ->and($turno->disputa['nota_admin'])->toBe('Serviço prestado conforme combinado.')
        ->and($turno->disputa['resolvida_por'])->toBe($admin->id)
        ->and($turno->disputa['resolvida_em'])->not->toBeNull()
        // CA-3 — a abertura permanece intacta (trilha completa: quem abriu + quem resolveu).
        ->and($turno->disputa['aberta_por'])->toBe($turno->contratante_id)
        ->and($turno->disputa['justificativa_contratante'])->toBe('O profissional saiu 40 min antes do fim combinado.')
        ->and($turno->check_out_at)->not->toBeNull(); // transição carimba o fim

    $log = AuditLog::query()->where('action', 'turno.disputa_resolvida')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBe($admin->id)
        ->and($log->payload['resolucao'])->toBe('paga_integral');

    // CA-2/CA-7 — reusa LITERALMENTE o evento do check-out feliz (captura+Pix, notificação, gate).
    Event::assertDispatched(TurnoFinalizado::class, fn ($e) => $e->turnoId === $turno->id);
});

test('CA-3: a nota_admin é trimada ao persistir', function () {
    $admin = User::factory()->admin()->ativo()->create();
    $turno = turnoParaResolver();

    resolverDisputa($turno, $admin, ['nota_admin' => '   decisão fundamentada   '])->assertStatus(200);

    expect($turno->refresh()->disputa['nota_admin'])->toBe('decisão fundamentada');
});

// ── CA-1/CA-2/CA-6/CA-7 — ponta a ponta: captura+Pix real disparada pelo comando ──

test('CA-1/CA-2/CA-7: o comando do admin enfileira a captura+Pix e notifica o profissional', function () {
    // Queue::fake intercepta o job financeiro (que se fixa na fila `database` — STORY-065); os
    // LISTENERS de evento rodam síncronos, então a notificação in-app é escrita de verdade.
    Queue::fake();
    $admin = User::factory()->admin()->ativo()->create();
    $turno = turnoParaResolver();

    resolverDisputa($turno, $admin)->assertStatus(200);

    // CA-1 — o MESMO job de captura+Pix do check-out feliz é enfileirado (motor financeiro do 065).
    Queue::assertPushed(CapturarEPagarTurnoJob::class, fn ($job) => $job->turnoId === $turno->id);

    // CA-2/CA-7 — finalizado, com notificação de finalização ao profissional (reuso do 067).
    expect($turno->refresh()->status)->toBe(TurnoStatus::Finalizado)
        ->and(Notificacao::where('destinatario_id', $turno->profissional_id)->where('tipo', NotificacaoTipo::TurnoFinalizado)->exists())->toBeTrue();
});

// ── CA-4 — idempotência: 2º "pagar integral" não captura/paga em dobro ─────────

test('CA-4: 2º clique em resolver → 422 estado_invalido, captura enfileirada uma só vez', function () {
    Queue::fake();
    $admin = User::factory()->admin()->ativo()->create();
    $turno = turnoParaResolver();

    resolverDisputa($turno, $admin, ['nota_admin' => 'primeira'])->assertStatus(200);
    resolverDisputa($turno->fresh(), $admin, ['nota_admin' => 'segunda'])
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');

    // O 2º "pagar integral" para no guard de estado (já finalizado): trilha intacta, sem 2º
    // evento. A captura+Pix é enfileirada UMA vez; a idempotência financeira fina (índice único)
    // é do 056/065. 1 só audit de resolução.
    expect($turno->refresh()->disputa['nota_admin'])->toBe('primeira');
    Queue::assertPushed(CapturarEPagarTurnoJob::class, 1);
    expect(AuditLog::where('action', 'turno.disputa_resolvida')->where('target_id', $turno->id)->count())->toBe(1);
});

// ── CA-5 — RBAC fail-secure + estado errado ───────────────────────────────────

test('CA-5: sem o segredo do canal → 401, nenhum efeito', function () {
    $admin = User::factory()->admin()->ativo()->create();
    $turno = turnoParaResolver();

    resolverDisputa($turno, $admin, [], token: '')->assertStatus(401);

    expect($turno->refresh()->status)->toBe(TurnoStatus::EmDisputa)
        ->and($turno->disputa['resolucao'])->toBeNull();
});

test('CA-5: segredo do canal errado → 401', function () {
    $admin = User::factory()->admin()->ativo()->create();
    $turno = turnoParaResolver();

    resolverDisputa($turno, $admin, [], token: 'token-errado')->assertStatus(401);

    expect($turno->refresh()->status)->toBe(TurnoStatus::EmDisputa);
});

test('CA-5: admin_id que NÃO é admin (contratante) → 403, fail-secure', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $turno = turnoParaResolver();

    resolverDisputa($turno, $contratante)->assertStatus(403);

    expect($turno->refresh()->status)->toBe(TurnoStatus::EmDisputa)
        ->and($turno->disputa['resolucao'])->toBeNull();
});

test('CA-5: admin_id que NÃO é admin (profissional) → 403', function () {
    $profissional = User::factory()->profissional()->ativo()->create();
    $turno = turnoParaResolver();

    resolverDisputa($turno, $profissional)->assertStatus(403);
});

test('CA-5: admin_id inexistente → 403', function () {
    $turno = turnoParaResolver();

    test()->postJson("/api/internal/turnos/{$turno->id}/resolver-disputa", [
        'admin_id' => '00000000-0000-7000-8000-000000000000',
        'nota_admin' => 'x',
    ], ['X-Internal-Token' => tokenInterno()])->assertStatus(403);
});

test('CA-5: resolver turno fora de em_disputa (ativo) → 422 estado_invalido, sem efeito', function () {
    $admin = User::factory()->admin()->ativo()->create();
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create(['check_in_at' => now()->subHours(2)]);

    resolverDisputa($turno, $admin)
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido')
        ->assertJsonPath('estado', 'ativo');

    expect($turno->refresh()->status)->toBe(TurnoStatus::Ativo);
});

// ── nota_admin obrigatória (decisão: seguir ADR-020 Dec.3, não o "opcional" da CA-3) ──

test('nota_admin ausente → 422 de validação, estado intacto', function () {
    $admin = User::factory()->admin()->ativo()->create();
    $turno = turnoParaResolver();

    test()->postJson("/api/internal/turnos/{$turno->id}/resolver-disputa", [
        'admin_id' => $admin->id,
    ], ['X-Internal-Token' => tokenInterno()])->assertStatus(422);

    expect($turno->refresh()->status)->toBe(TurnoStatus::EmDisputa);
});

test('nota_admin só com espaços → 422 (TrimStrings → required), sem audit', function () {
    $admin = User::factory()->admin()->ativo()->create();
    $turno = turnoParaResolver();

    resolverDisputa($turno, $admin, ['nota_admin' => '     '])->assertStatus(422);

    expect(AuditLog::where('action', 'turno.disputa_resolvida')->count())->toBe(0);
});

// ── núcleo do serviço (defesa em profundidade — chamadas não-HTTP) ─────────────

test('núcleo: o serviço rejeita nota_admin vazia sem tocar o estado', function () {
    $admin = User::factory()->admin()->ativo()->create();
    $turno = turnoParaResolver();

    expect(fn () => app(ResolverDisputaService::class)->resolverPagaIntegral($turno, $admin, '   '))
        ->toThrow(NotaAdminObrigatoriaException::class);

    expect($turno->refresh()->status)->toBe(TurnoStatus::EmDisputa)
        ->and(DB::table('pagamento_operacoes')->count())->toBe(0);
});

test('núcleo: o serviço recusa turno fora de em_disputa (finalizado)', function () {
    $admin = User::factory()->admin()->ativo()->create();
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();

    expect(fn () => app(ResolverDisputaService::class)->resolverPagaIntegral($turno->fresh(), $admin, 'tarde demais'))
        ->toThrow(PinCheckinEstadoInvalidoException::class);
});
