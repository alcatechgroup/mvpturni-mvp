<?php

// STORY-061 (CA-1..CA-4, CA-6..CA-8) — POST /api/turnos/{turno}/gerar-pin-checkin.
// Profissional em `confirmado`, dentro da janela [data_inicio−antes, data_inicio+depois]
// (config/env), gera PIN de 4 dígitos: hash bcrypt server-side (plaintext SÓ na resposta —
// CA-4), transição confirmado→aguardando_checkin em transação com o snapshot
// geofencing_check_in (Geofencing/Haversine — reuso STORY-057/049) e audit log
// turno.checkin_solicitado (CA-7, sem PIN no payload). PDR-008: geo nunca bloqueia.

use App\Enums\TurnoStatus;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Testing\TestResponse;

uses(RefreshDatabase::class);

/** Turno `confirmado` dentro da janela de check-in, vaga geolocalizada (SP centro). */
function turnoNaJanela(TurnoStatus $status = TurnoStatus::Confirmado): Turno
{
    $turno = Turno::factory()->status($status)->create([
        'data_inicio' => now()->addMinutes(15),
        'data_fim' => now()->addHours(6),
    ]);
    $turno->vaga->update(['lat' => -23.55, 'lng' => -46.63]);

    return $turno->fresh(['vaga', 'profissional', 'contratante']);
}

function gerarPin(Turno $turno, array $body = []): TestResponse
{
    return test()->actingAs($turno->profissional)
        ->postJson("/api/turnos/{$turno->id}/gerar-pin-checkin", [
            'pin_solicitado' => true,
            'lat' => -23.550135, // ~15m do estabelecimento
            'lng' => -46.630000,
            ...$body,
        ]);
}

// ── (a) caminho feliz ────────────────────────────────────────────────────────

test('na janela com geo no raio → 200 com PIN de 4 dígitos, aguardando_checkin, hash persistido e snapshot ok', function () {
    $turno = turnoNaJanela();

    $res = gerarPin($turno, ['accuracy_m' => 12.5]);

    $res->assertStatus(200)
        ->assertJsonPath('estado', 'aguardando_checkin')
        ->assertJsonPath('geofencing_check_in.ok', true)
        ->assertJsonPath('geofencing_check_in.razao', null);

    $pin = $res->json('pin');
    expect($pin)->toMatch('/^\d{4}$/');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::AguardandoCheckin)
        ->and($turno->pin_checkin_hash)->not->toBeNull()
        ->and($turno->pin_checkin_hash)->not->toBe($pin)            // nunca plaintext no banco
        ->and(Hash::check($pin, $turno->pin_checkin_hash))->toBeTrue()
        ->and($turno->geofencing_check_in['ok'])->toBeTrue()
        ->and($turno->geofencing_check_in)->toHaveKey('capturado_em')
        ->and((float) $turno->geofencing_check_in['distancia_metros'])->toBeLessThan(100.0);
});

test('CA-7: audit log turno.checkin_solicitado com snapshot completo e SEM o PIN', function () {
    $turno = turnoNaJanela();

    $res = gerarPin($turno);

    $log = AuditLog::query()
        ->where('action', 'turno.checkin_solicitado')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)
        ->first();

    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBe($turno->profissional_id)
        ->and($log->payload['geofencing_check_in']['ok'])->toBeTrue()
        ->and($log->payload['geofencing_check_in'])->toHaveKeys(['distancia_metros', 'capturado_em'])
        ->and($log->payload['pin_regerado'])->toBeFalse();

    // CA-4 — o PIN plaintext não existe em NENHUM lugar além da resposta.
    expect(json_encode($log->payload))->not->toContain($res->json('pin'));
    expect(array_keys($log->payload))->not->toContain('pin');
});

// ── (b) janela (CA-1) ────────────────────────────────────────────────────────

test('antes da janela → 422 fora_da_janela, estado intacto e sem hash', function () {
    $turno = turnoNaJanela();
    $turno->forceFill(['data_inicio' => now()->addHours(3), 'data_fim' => now()->addHours(9)])->save();

    gerarPin($turno->fresh(['vaga', 'profissional']))
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'fora_da_janela')
        ->assertJsonStructure(['janela' => ['abre_em', 'fecha_em']]);

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::Confirmado)
        ->and($turno->pin_checkin_hash)->toBeNull();
});

test('depois da janela → 422 fora_da_janela', function () {
    $turno = turnoNaJanela();
    $turno->forceFill(['data_inicio' => now()->subHours(3), 'data_fim' => now()->addHours(3)])->save();

    gerarPin($turno->fresh(['vaga', 'profissional']))
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'fora_da_janela');
});

test('bordas inclusivas: exatamente na abertura e no fechamento da janela → 200', function () {
    // Congela o relógio em segundo cheio: a borda é exata e o banco trunca microssegundos.
    $this->travelTo(now()->startOfSecond());

    $abre = turnoNaJanela();
    $abre->forceFill(['data_inicio' => now()->addMinutes(30), 'data_fim' => now()->addHours(7)])->save();
    gerarPin($abre->fresh(['vaga', 'profissional']))->assertStatus(200);

    $fecha = turnoNaJanela();
    $fecha->forceFill(['data_inicio' => now()->subMinutes(120), 'data_fim' => now()->addHours(2)])->save();
    gerarPin($fecha->fresh(['vaga', 'profissional']))->assertStatus(200);
});

test('janela é configurável via config/env', function () {
    config(['turno.checkin_janela_antes_min' => 5]);

    // 15min antes do início: dentro do default (30) mas FORA da janela de 5min.
    gerarPin(turnoNaJanela())->assertStatus(422)->assertJsonPath('motivo', 'fora_da_janela');
});

// ── (b) estado (CA-3) ────────────────────────────────────────────────────────

test('estado que não gera PIN (ativo) → 422 estado_invalido', function () {
    gerarPin(turnoNaJanela(TurnoStatus::Ativo))
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

test('estado terminal (finalizado) → 422 estado_invalido', function () {
    gerarPin(turnoNaJanela(TurnoStatus::Finalizado))
        ->assertStatus(422)
        ->assertJsonPath('motivo', 'estado_invalido');
});

// ── (b) payload inválido ─────────────────────────────────────────────────────

test('lat fora do intervalo → 422 de validação', function () {
    gerarPin(turnoNaJanela(), ['lat' => -200])->assertStatus(422);
});

test('razao inválida → 422 de validação', function () {
    gerarPin(turnoNaJanela(), ['lat' => null, 'lng' => null, 'razao' => 'qualquer'])->assertStatus(422);
});

// ── (c) RBAC (CA-8) e autenticação ───────────────────────────────────────────

test('contratante não gera PIN → 403', function () {
    $turno = turnoNaJanela();

    test()->actingAs($turno->contratante)
        ->postJson("/api/turnos/{$turno->id}/gerar-pin-checkin", ['pin_solicitado' => true])
        ->assertStatus(403);
});

test('terceiro → 403', function () {
    $turno = turnoNaJanela();
    $estranho = User::factory()->profissional()->ativo()->create();

    test()->actingAs($estranho)
        ->postJson("/api/turnos/{$turno->id}/gerar-pin-checkin", ['pin_solicitado' => true])
        ->assertStatus(403);
});

test('não autenticado → 401', function () {
    $turno = turnoNaJanela();

    test()->postJson("/api/turnos/{$turno->id}/gerar-pin-checkin", ['pin_solicitado' => true])
        ->assertStatus(401);
});

// ── (d) geofencing nunca bloqueia (PDR-008 / CA-2 / CA-6) ────────────────────

test('geo negada → PIN gerado mesmo assim; snapshot ok:false com razão preservada', function () {
    $turno = turnoNaJanela();

    $res = gerarPin($turno, ['lat' => null, 'lng' => null, 'razao' => 'permissao_negada']);

    $res->assertStatus(200)
        ->assertJsonPath('geofencing_check_in.ok', false)
        ->assertJsonPath('geofencing_check_in.distancia_metros', null)
        ->assertJsonPath('geofencing_check_in.razao', 'permissao_negada');

    expect($res->json('pin'))->toMatch('/^\d{4}$/');
});

test('timeout de captura → snapshot com razao timeout e PIN gerado', function () {
    gerarPin(turnoNaJanela(), ['lat' => null, 'lng' => null, 'razao' => 'timeout'])
        ->assertStatus(200)
        ->assertJsonPath('geofencing_check_in.razao', 'timeout');
});

test('fora do raio → ok:false com distância e razao fora_do_raio; PIN gerado (alerta, não bloqueia)', function () {
    $turno = turnoNaJanela();

    $res = gerarPin($turno, ['lat' => -23.541000, 'lng' => -46.630000]); // ~1km

    $res->assertStatus(200)
        ->assertJsonPath('geofencing_check_in.ok', false)
        ->assertJsonPath('geofencing_check_in.razao', 'fora_do_raio');

    expect((float) $res->json('geofencing_check_in.distancia_metros'))->toBeGreaterThan(900.0);
});

// ── (d) re-geração (CA-5 idempotente — invalida o hash anterior) ─────────────

test('re-geração em aguardando_checkin → novo PIN, hash anterior invalidado, audit pin_regerado', function () {
    $turno = turnoNaJanela();

    $pin1 = gerarPin($turno)->assertStatus(200)->json('pin');
    $pin2 = gerarPin($turno->fresh(['vaga', 'profissional']))->assertStatus(200)->json('pin');

    $turno->refresh();
    expect($turno->status)->toBe(TurnoStatus::AguardandoCheckin)
        ->and(Hash::check($pin2, $turno->pin_checkin_hash))->toBeTrue();

    // O hash vigente é o do PIN novo; o anterior só coincidiria se pin1 === pin2.
    if ($pin1 !== $pin2) {
        expect(Hash::check($pin1, $turno->pin_checkin_hash))->toBeFalse();
    }

    $logs = AuditLog::query()->where('action', 'turno.checkin_solicitado')
        ->where('target_id', $turno->id)->orderBy('created_at')->get();
    expect($logs)->toHaveCount(2)
        ->and($logs[0]->payload['pin_regerado'])->toBeFalse()
        ->and($logs[1]->payload['pin_regerado'])->toBeTrue();
});
