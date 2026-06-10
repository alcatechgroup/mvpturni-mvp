<?php

// STORY-092 / ADR-020 (Decisão 2) — POST /api/turnos/{turno}/abrir-disputa.
// O OUTRO ramo de `aguardando_checkout` (contestar por mérito), distinto de /recusar-checkout:
// transita para `em_disputa` com justificativa OBRIGATÓRIA, grava `turnos.disputa` (jsonb),
// MANTÉM a pré-autorização bloqueada (nenhuma operação financeira), audita turno.disputa_aberta
// e emite DisputaAberta (notifica o profissional). RBAC fail-secure: só o contratante dono.

use App\Enums\TurnoStatus;
use App\Events\DisputaAberta;
use App\Events\TurnoFinalizado;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Models\User;
use App\Services\AbrirDisputaService;
use App\Services\DisputaSemJustificativaException;
use App\Services\PinCheckinEstadoInvalidoException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Testing\TestResponse;

uses(RefreshDatabase::class);

/** Turno `aguardando_checkout` com PIN de check-out vigente (espelho da RecusarCheckoutTest). */
function turnoEmCheckout(): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckout)->create([
        'data_inicio' => now()->subHours(5),
        'data_fim' => now()->subMinutes(10),
        'check_in_at' => now()->subHours(5),
        'pin_checkout_hash' => Hash::make('8341'),
        'pin_checkout_tentativas' => 1,
    ]);

    return $turno->fresh(['profissional', 'contratante']);
}

function abrirDisputa(Turno $turno, array $body = []): TestResponse
{
    return test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/abrir-disputa", $body);
}

// ── CA-1 — abertura feliz ─────────────────────────────────────────────────────

test('CA-1: contratante abre disputa com justificativa → 200 em_disputa, disputa jsonb e audit', function () {
    $turno = turnoEmCheckout();

    abrirDisputa($turno, ['justificativa' => 'O profissional saiu 40 min antes do fim combinado.'])
        ->assertStatus(200)
        ->assertJsonPath('estado', 'em_disputa');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::EmDisputa)
        ->and($turno->disputa['aberta_por'])->toBe($turno->contratante_id)   // sempre o contratante
        ->and($turno->disputa['justificativa_contratante'])->toBe('O profissional saiu 40 min antes do fim combinado.')
        ->and($turno->disputa['aberta_em'])->not->toBeNull()
        ->and($turno->disputa['resolucao'])->toBeNull()                       // só a STORY-093 preenche
        ->and($turno->disputa['nota_admin'])->toBeNull()
        ->and($turno->disputa['resolvida_em'])->toBeNull()
        ->and($turno->disputa['resolvida_por'])->toBeNull()
        ->and($turno->pin_checkout_hash)->toBeNull()                          // PIN deixa de valer
        ->and($turno->check_out_at)->toBeNull();                              // não finalizou

    $log = AuditLog::query()->where('action', 'turno.disputa_aberta')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBe($turno->contratante_id)
        ->and($log->payload['justificativa'])->toBe('O profissional saiu 40 min antes do fim combinado.');
});

test('CA-1: a justificativa é trimada ao persistir e auditar', function () {
    $turno = turnoEmCheckout();

    abrirDisputa($turno, ['justificativa' => '   houve divergência no valor   '])->assertStatus(200);

    expect($turno->refresh()->disputa['justificativa_contratante'])->toBe('houve divergência no valor');
});

// ── CA-2 — justificativa obrigatória ──────────────────────────────────────────

test('CA-2: justificativa ausente → 422 de validação, estado intacto', function () {
    $turno = turnoEmCheckout();

    abrirDisputa($turno)->assertStatus(422);

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::AguardandoCheckout)
        ->and($turno->disputa)->toBeNull();
});

test('CA-2: justificativa só com espaços → 422, estado intacto, sem audit', function () {
    // O middleware TrimStrings zera "     " antes da validação → cai no `required` (422 de
    // validação). O guard de domínio (trim → DisputaSemJustificativaException) é a 2ª camada,
    // coberta pelo teste de núcleo abaixo (defesa em profundidade para chamadas não-HTTP).
    $turno = turnoEmCheckout();

    abrirDisputa($turno, ['justificativa' => '     '])->assertStatus(422);

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::AguardandoCheckout)
        ->and($turno->disputa)->toBeNull();
    expect(AuditLog::where('action', 'turno.disputa_aberta')->count())->toBe(0);
});

test('CA-2 (núcleo): o serviço rejeita justificativa vazia sem tocar o estado', function () {
    $turno = turnoEmCheckout();

    expect(fn () => app(AbrirDisputaService::class)->abrir($turno, '   '))
        ->toThrow(DisputaSemJustificativaException::class);

    expect($turno->refresh()->status)->toBe(TurnoStatus::AguardandoCheckout);
});

// ── CA-3 — pré-autorização permanece bloqueada ────────────────────────────────

test('CA-3: abrir disputa NÃO dispara nada financeiro (pré-autorização intacta)', function () {
    Event::fake([DisputaAberta::class, TurnoFinalizado::class]);
    $turno = turnoEmCheckout();

    abrirDisputa($turno, ['justificativa' => 'valor combinado divergente'])->assertStatus(200);

    // Nenhuma operação de pagamento criada — a captura só ocorre via TurnoFinalizado/`finalizado`.
    expect(DB::table('pagamento_operacoes')->count())->toBe(0);
    Event::assertDispatched(DisputaAberta::class, fn ($e) => $e->turnoId === $turno->id);
    Event::assertNotDispatched(TurnoFinalizado::class);
});

// ── CA-4 — só a partir de aguardando_checkout ─────────────────────────────────

test('CA-4: abrir disputa fora de aguardando_checkout (ativo) → 422 estado_invalido, sem efeito', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create(['check_in_at' => now()->subHours(2)]);

    abrirDisputa($turno->fresh(['contratante']), ['justificativa' => 'tentando contestar cedo demais'])
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido')
        ->assertJsonPath('estado', 'ativo');

    expect($turno->refresh()->disputa)->toBeNull();
});

test('CA-4 (núcleo): o serviço recusa estado terminal (finalizado)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();

    expect(fn () => app(AbrirDisputaService::class)->abrir($turno->fresh(), 'tarde demais'))
        ->toThrow(PinCheckinEstadoInvalidoException::class);
});

// ── CA-5 — RBAC fail-secure ───────────────────────────────────────────────────

test('CA-5: profissional do turno não abre disputa → 403', function () {
    $turno = turnoEmCheckout();

    test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/abrir-disputa", ['justificativa' => 'x'])
        ->assertStatus(403);

    expect($turno->refresh()->status)->toBe(TurnoStatus::AguardandoCheckout);
});

test('CA-5: outro contratante (não-dono) não abre disputa → 403, sem vazamento', function () {
    $turno = turnoEmCheckout();
    $estranho = User::factory()->contratante()->ativo()->create();

    test()->actingAs($estranho)
        ->postJson("/api/turnos/{$turno->id}/abrir-disputa", ['justificativa' => 'x'])
        ->assertStatus(403);

    expect($turno->refresh()->disputa)->toBeNull();
});

test('CA-5: não autenticado → 401', function () {
    $turno = turnoEmCheckout();

    test()->postJson("/api/turnos/{$turno->id}/abrir-disputa", ['justificativa' => 'x'])
        ->assertStatus(401);
});

// ── CA-7 — consultável como pendência do admin (derivada do estado) ───────────

test('CA-7: o turno aberto é consultável pela fila do admin (WHERE status = em_disputa)', function () {
    $turno = turnoEmCheckout();

    abrirDisputa($turno, ['justificativa' => 'pendência para o admin'])->assertStatus(200);

    $fila = Turno::query()->where('status', TurnoStatus::EmDisputa)->pluck('id');
    expect($fila->all())->toContain($turno->id);
});

// ── idempotência da abertura (2º clique) ──────────────────────────────────────

test('2º clique em abrir-disputa → 422 estado_invalido (já em_disputa); 1 só evento/audit', function () {
    $turno = turnoEmCheckout();

    abrirDisputa($turno, ['justificativa' => 'primeira'])->assertStatus(200);
    abrirDisputa($turno->fresh(['contratante']), ['justificativa' => 'segunda'])
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');

    expect(AuditLog::where('action', 'turno.disputa_aberta')->where('target_id', $turno->id)->count())->toBe(1)
        ->and($turno->refresh()->disputa['justificativa_contratante'])->toBe('primeira');
});
