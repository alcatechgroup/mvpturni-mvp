<?php

// STORY-057 / ADR-017 (decisão b) — POST /api/turnos/{turno}/checkin-geo: PoC do geofencing de
// check-in. A posição do navegador chega ao backend e a distância em metros é calculada via
// Haversine (reuso STORY-049), gravando o snapshot geofencing_check_in (PDR-008, alerta-e-registra).

use App\Enums\TurnoStatus;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/** Turno aguardando check-in, com vaga geolocalizada no estabelecimento (SP centro). */
function turnoCheckin(): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::AguardandoCheckin)->create();
    $turno->vaga->update(['lat' => -23.55, 'lng' => -46.63]);

    return $turno->fresh(['vaga', 'profissional', 'contratante']);
}

test('profissional dentro do raio → ok:true + distância em metros, snapshot persistido', function () {
    $turno = turnoCheckin();

    $res = $this->actingAs($turno->profissional)->postJson("/api/turnos/{$turno->id}/checkin-geo", [
        'lat' => -23.550135, // ~15m ao sul do estabelecimento (mesma longitude)
        'lng' => -46.630000,
    ]);

    $res->assertStatus(200)
        ->assertJsonStructure(['ok', 'distancia_metros', 'razao', 'capturado_em'])
        ->assertJsonPath('ok', true)
        ->assertJsonPath('razao', null);

    expect($res->json('distancia_metros'))->toBeGreaterThan(10.0)->toBeLessThan(20.0);

    // Snapshot persistido na trilha de auditoria do turno.
    $turno->refresh();
    expect($turno->geofencing_check_in['ok'])->toBeTrue();
    expect($turno->geofencing_check_in)->toHaveKey('capturado_em');
});

test('profissional fora do raio → ok:false, razao fora_do_raio, distância preenchida', function () {
    $turno = turnoCheckin();

    $res = $this->actingAs($turno->profissional)->postJson("/api/turnos/{$turno->id}/checkin-geo", [
        'lat' => -23.541000, // ~1km ao norte (mesma longitude)
        'lng' => -46.630000,
    ]);

    $res->assertStatus(200)
        ->assertJsonPath('ok', false)
        ->assertJsonPath('razao', 'fora_do_raio');

    expect($res->json('distancia_metros'))->toBeGreaterThan(900.0);
});

test('sem coordenada (permissão negada) → ok:false, distância null, razao preservada', function () {
    $turno = turnoCheckin();

    $this->actingAs($turno->profissional)->postJson("/api/turnos/{$turno->id}/checkin-geo", [
        'lat' => null,
        'lng' => null,
        'razao' => 'permissao_negada',
    ])
        ->assertStatus(200)
        ->assertJsonPath('ok', false)
        ->assertJsonPath('distancia_metros', null)
        ->assertJsonPath('razao', 'permissao_negada');
});

test('contratante não faz check-in geo (só o profissional) → 404', function () {
    $turno = turnoCheckin();

    $this->actingAs($turno->contratante)->postJson("/api/turnos/{$turno->id}/checkin-geo", [
        'lat' => -23.55, 'lng' => -46.63,
    ])->assertStatus(404);
});

test('terceiro → 404', function () {
    $turno = turnoCheckin();
    $estranho = User::factory()->profissional()->ativo()->create();

    $this->actingAs($estranho)->postJson("/api/turnos/{$turno->id}/checkin-geo", [
        'lat' => -23.55, 'lng' => -46.63,
    ])->assertStatus(404);
});

test('não autenticado → 401', function () {
    $turno = turnoCheckin();

    $this->postJson("/api/turnos/{$turno->id}/checkin-geo", ['lat' => -23.55, 'lng' => -46.63])
        ->assertStatus(401);
});

test('lat fora do intervalo → 422', function () {
    $turno = turnoCheckin();

    $this->actingAs($turno->profissional)->postJson("/api/turnos/{$turno->id}/checkin-geo", [
        'lat' => -200, 'lng' => -46.63,
    ])->assertStatus(422);
});

test('razao inválida → 422', function () {
    $turno = turnoCheckin();

    $this->actingAs($turno->profissional)->postJson("/api/turnos/{$turno->id}/checkin-geo", [
        'razao' => 'qualquer_coisa',
    ])->assertStatus(422);
});
