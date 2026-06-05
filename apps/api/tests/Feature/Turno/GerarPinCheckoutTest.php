<?php

// STORY-064 (CA-1/CA-2/CA-7) — POST /api/turnos/{turno}/gerar-pin-checkout.
// Profissional em `ativo` gera PIN de check-out de 4 dígitos: hash bcrypt server-side
// (plaintext SÓ na resposta), transição ativo→aguardando_checkout em transação com o
// snapshot geofencing_check_out e audit turno.checkout_solicitado (o cronômetro da 063
// deriva o encerrado_em exibido deste evento). Diferenças intencionais da 061: SEM
// janela horária (CA-1 — turno pode estender) e geofencing opcional/silencioso (CA-2).

use App\Enums\TurnoStatus;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Testing\TestResponse;

uses(RefreshDatabase::class);

/** Turno `ativo` (check-in validado há 5h), vaga geolocalizada (SP centro). */
function turnoAtivoParaCheckout(TurnoStatus $status = TurnoStatus::Ativo): Turno
{
    $turno = Turno::factory()->status($status)->create([
        'data_inicio' => now()->subHours(5),
        'data_fim' => now()->subMinutes(10),
        'check_in_at' => $status === TurnoStatus::Confirmado ? null : now()->subHours(5),
    ]);
    $turno->vaga->update(['lat' => -23.55, 'lng' => -46.63]);

    return $turno->fresh(['vaga', 'profissional', 'contratante']);
}

function gerarPinCheckout(Turno $turno, array $body = []): TestResponse
{
    return test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/gerar-pin-checkout", [
            'pin_solicitado' => true,
            'lat' => -23.550135, // ~15m do estabelecimento
            'lng' => -46.630000,
            ...$body,
        ]);
}

// ── (a) caminho feliz (CA-2) ─────────────────────────────────────────────────

test('em ativo → 200 com PIN de 4 dígitos, aguardando_checkout, hash persistido e snapshot ok', function () {
    $turno = turnoAtivoParaCheckout();

    $res = gerarPinCheckout($turno, ['accuracy_m' => 12.5]);

    $res->assertStatus(200)
        ->assertJsonPath('estado', 'aguardando_checkout')
        ->assertJsonPath('geofencing_check_out.ok', true)
        ->assertJsonPath('geofencing_check_out.razao', null);

    $pin = $res->json('pin');
    expect($pin)->toMatch('/^\d{4}$/');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::AguardandoCheckout)
        ->and($turno->pin_checkout_hash)->not->toBeNull()
        ->and($turno->pin_checkout_hash)->not->toBe($pin)           // nunca plaintext no banco
        ->and(Hash::check($pin, $turno->pin_checkout_hash))->toBeTrue()
        ->and($turno->geofencing_check_out['ok'])->toBeTrue()
        ->and($turno->geofencing_check_out)->toHaveKey('capturado_em')
        ->and($turno->check_in_at)->not->toBeNull()                 // âncora do cronômetro intacta
        ->and($turno->check_out_at)->toBeNull();                    // final só na validação (CA-3)
});

test('CA-7: audit log turno.checkout_solicitado com snapshot completo e SEM o PIN', function () {
    $turno = turnoAtivoParaCheckout();

    $res = gerarPinCheckout($turno);

    $log = AuditLog::query()
        ->where('action', 'turno.checkout_solicitado')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)
        ->first();

    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBe($turno->profissional_id)
        ->and($log->payload['geofencing_check_out']['ok'])->toBeTrue()
        ->and($log->payload['geofencing_check_out'])->toHaveKeys(['distancia_metros', 'capturado_em'])
        ->and($log->payload['pin_regerado'])->toBeFalse();

    // O PIN plaintext não existe em NENHUM lugar além da resposta.
    expect(json_encode($log->payload))->not->toContain($res->json('pin'));
    expect(array_keys($log->payload))->not->toContain('pin');
});

// ── (b) SEM janela horária (CA-1 — diferença intencional da 061) ─────────────

test('turno que estendeu muito além de data_fim ainda gera o PIN (sem janela restritiva)', function () {
    $turno = turnoAtivoParaCheckout();
    // Previsto 14h→6h atrás; o profissional estendeu e só agora faz o check-out.
    $turno->forceFill([
        'data_inicio' => now()->subHours(14),
        'data_fim' => now()->subHours(6),
        'check_in_at' => now()->subHours(14),
    ])->save();

    gerarPinCheckout($turno->fresh(['vaga', 'profissional']))->assertStatus(200);
});

test('turno antes de data_fim (saída antecipada) também gera o PIN', function () {
    $turno = turnoAtivoParaCheckout();
    $turno->forceFill(['data_fim' => now()->addHours(2)])->save();

    gerarPinCheckout($turno->fresh(['vaga', 'profissional']))->assertStatus(200);
});

// ── (c) estado ───────────────────────────────────────────────────────────────

test('estado que não gera PIN de check-out (confirmado) → 422 estado_invalido', function () {
    gerarPinCheckout(turnoAtivoParaCheckout(TurnoStatus::Confirmado))
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

test('estado terminal (finalizado) → 422 estado_invalido', function () {
    gerarPinCheckout(turnoAtivoParaCheckout(TurnoStatus::Finalizado))
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

// ── (d) payload inválido ─────────────────────────────────────────────────────

test('lat fora do intervalo → 422 de validação (checkout)', function () {
    gerarPinCheckout(turnoAtivoParaCheckout(), ['lat' => -200])->assertStatus(422);
});

test('razao inválida → 422 de validação (checkout)', function () {
    gerarPinCheckout(turnoAtivoParaCheckout(), ['lat' => null, 'lng' => null, 'razao' => 'qualquer'])
        ->assertStatus(422);
});

// ── (e) RBAC e autenticação ──────────────────────────────────────────────────

test('contratante não gera PIN de check-out → 403', function () {
    $turno = turnoAtivoParaCheckout();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/gerar-pin-checkout", ['pin_solicitado' => true])
        ->assertStatus(403);
});

test('terceiro não gera PIN de check-out → 403', function () {
    $turno = turnoAtivoParaCheckout();
    $estranho = User::factory()->profissional()->ativo()->create();

    test()->actingAs($estranho)
        ->postJson("/api/turnos/{$turno->id}/gerar-pin-checkout", ['pin_solicitado' => true])
        ->assertStatus(403);
});

test('não autenticado não gera PIN de check-out → 401', function () {
    $turno = turnoAtivoParaCheckout();

    test()->postJson("/api/turnos/{$turno->id}/gerar-pin-checkout", ['pin_solicitado' => true])
        ->assertStatus(401);
});

// ── (f) geofencing opcional, nunca bloqueia (CA-2 / PDR-008) ─────────────────

test('geo negada → PIN de check-out gerado mesmo assim; snapshot ok:false com razão', function () {
    $res = gerarPinCheckout(turnoAtivoParaCheckout(), ['lat' => null, 'lng' => null, 'razao' => 'permissao_negada']);

    $res->assertStatus(200)
        ->assertJsonPath('geofencing_check_out.ok', false)
        ->assertJsonPath('geofencing_check_out.distancia_metros', null)
        ->assertJsonPath('geofencing_check_out.razao', 'permissao_negada');

    expect($res->json('pin'))->toMatch('/^\d{4}$/');
});

test('fora do raio → ok:false com distância; PIN de check-out gerado (registra, não bloqueia)', function () {
    $res = gerarPinCheckout(turnoAtivoParaCheckout(), ['lat' => -23.541000, 'lng' => -46.630000]); // ~1km

    $res->assertStatus(200)
        ->assertJsonPath('geofencing_check_out.ok', false)
        ->assertJsonPath('geofencing_check_out.razao', 'fora_do_raio');
});

// ── (g) re-geração (idempotente — invalida o hash anterior) ──────────────────

test('re-geração em aguardando_checkout → novo PIN, hash anterior invalidado, audit pin_regerado', function () {
    $turno = turnoAtivoParaCheckout();

    $pin1 = gerarPinCheckout($turno)->assertStatus(200)->json('pin');
    $pin2 = gerarPinCheckout($turno->fresh(['vaga', 'profissional']))->assertStatus(200)->json('pin');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::AguardandoCheckout)
        ->and(Hash::check($pin2, $turno->pin_checkout_hash))->toBeTrue();

    // O hash vigente é o do PIN novo; o anterior só coincidiria se pin1 === pin2.
    if ($pin1 !== $pin2) {
        expect(Hash::check($pin1, $turno->pin_checkout_hash))->toBeFalse();
    }

    $logs = AuditLog::query()->where('action', 'turno.checkout_solicitado')
        ->where('target_id', $turno->id)->orderBy('created_at')->get();
    expect($logs)->toHaveCount(2)
        ->and($logs[0]->payload['pin_regerado'])->toBeFalse()
        ->and($logs[1]->payload['pin_regerado'])->toBeTrue();
});

test('re-geração zera o contador de erros de validação (PIN novo, chances novas)', function () {
    $turno = turnoAtivoParaCheckout();
    gerarPinCheckout($turno)->assertStatus(200);
    $turno->refresh()->forceFill(['pin_checkout_tentativas' => 2])->save();

    gerarPinCheckout($turno->fresh(['vaga', 'profissional']))->assertStatus(200);

    expect($turno->refresh()->pin_checkout_tentativas)->toBe(0);
});
