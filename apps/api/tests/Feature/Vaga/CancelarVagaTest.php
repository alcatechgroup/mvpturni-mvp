<?php

// STORY-047 — DELETE /api/vagas/{id}: contratante cancela vaga aberta (CA-4/CA-5).
// Cancelamento é SOFT (transição aberta→cancelada, não DELETE físico). Valida RBAC
// (dono), valida transição (409 fora de `aberta`), registra audit `vaga.cancelada`
// e dispara o evento de domínio `VagaCancelada` (consumido por STORY-053).

use App\Enums\VagaEstado;
use App\Events\VagaCancelada;
use App\Models\AuditLog;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;

uses(RefreshDatabase::class);

function vagaAberta(User $contratante, array $over = []): Vaga
{
    return Vaga::factory()->create(array_merge(['contratante_id' => $contratante->id], $over));
}

// ───────────────────────── CA-4/CA-5 — caminho feliz ─────────────────────────

test('contratante dono cancela vaga aberta → 200 + estado cancelada no banco (CA-4/CA-5)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $vaga = vagaAberta($contratante);

    $res = $this->actingAs($contratante)->deleteJson("/api/vagas/{$vaga->id}");

    $res->assertStatus(200)->assertJsonPath('estado', 'cancelada');

    $vaga->refresh();
    expect($vaga->estado)->toBe(VagaEstado::Cancelada)
        ->and($vaga->cancelada_em)->not->toBeNull();
});

test('cancelar registra audit_logs vaga.cancelada com ator e alvo (CA-5)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $vaga = vagaAberta($contratante);

    $this->actingAs($contratante)->deleteJson("/api/vagas/{$vaga->id}")->assertStatus(200);

    $log = AuditLog::where('action', 'vaga.cancelada')->where('target_id', $vaga->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->target_type)->toBe('Vaga')
        ->and($log->actor_id)->toBe($contratante->id);
});

test('cancelar dispara o evento de domínio VagaCancelada (CA-5)', function () {
    Event::fake([VagaCancelada::class]);
    $contratante = User::factory()->contratante()->ativo()->create();
    $vaga = vagaAberta($contratante);

    $this->actingAs($contratante)->deleteJson("/api/vagas/{$vaga->id}")->assertStatus(200);

    Event::assertDispatched(VagaCancelada::class, fn (VagaCancelada $e) => $e->vaga->id === $vaga->id);
});

// ───────────────────────── CA-1/CA-5 — RBAC ─────────────────────────

test('contratante NÃO-dono recebe 403 e a vaga continua aberta (CA-5)', function () {
    $dono = User::factory()->contratante()->ativo()->create();
    $outro = User::factory()->contratante()->ativo()->create();
    $vaga = vagaAberta($dono);

    $this->actingAs($outro)->deleteJson("/api/vagas/{$vaga->id}")->assertStatus(403);

    expect($vaga->refresh()->estado)->toBe(VagaEstado::Aberta);
});

test('profissional recebe 403 ao cancelar (CA-1)', function () {
    $dono = User::factory()->contratante()->ativo()->create();
    $prof = User::factory()->profissional()->ativo()->create();
    $vaga = vagaAberta($dono);

    $this->actingAs($prof)->deleteJson("/api/vagas/{$vaga->id}")->assertStatus(403);
    expect($vaga->refresh()->estado)->toBe(VagaEstado::Aberta);
});

test('não autenticado recebe 401 (exceção)', function () {
    $vaga = vagaAberta(User::factory()->contratante()->ativo()->create());

    $this->deleteJson("/api/vagas/{$vaga->id}")->assertStatus(401);
});

// ───────────────────────── CA-5 — transição inválida (409) ─────────────────────────

test('cancelar vaga fechada → 409 (transição inválida)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $vaga = Vaga::factory()->fechada()->create(['contratante_id' => $contratante->id]);

    $this->actingAs($contratante)->deleteJson("/api/vagas/{$vaga->id}")->assertStatus(409);
    expect($vaga->refresh()->estado)->toBe(VagaEstado::Fechada);
});

test('cancelar vaga já cancelada → 409 (idempotência fail-closed)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $vaga = Vaga::factory()->cancelada()->create(['contratante_id' => $contratante->id]);

    $this->actingAs($contratante)->deleteJson("/api/vagas/{$vaga->id}")->assertStatus(409);
});

// ───────────────────────── borda — recurso inexistente ─────────────────────────

test('cancelar vaga inexistente → 404 (borda)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();

    $this->actingAs($contratante)->deleteJson('/api/vagas/00000000-0000-0000-0000-000000000000')->assertStatus(404);
});

test('cancelar NÃO dispara evento quando a transição falha (409)', function () {
    Event::fake([VagaCancelada::class]);
    $contratante = User::factory()->contratante()->ativo()->create();
    $vaga = Vaga::factory()->fechada()->create(['contratante_id' => $contratante->id]);

    $this->actingAs($contratante)->deleteJson("/api/vagas/{$vaga->id}")->assertStatus(409);

    Event::assertNotDispatched(VagaCancelada::class);
});
