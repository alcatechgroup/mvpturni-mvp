<?php

// STORY-057 / ADR-017 (decisão a) — GET /api/turnos/{turno}/cronometro: âncora do cronômetro
// bilateral. Servidor é a fonte de verdade do tempo (CA-4): devolve iniciado_em (check_in_at) +
// servidor_agora; o cliente tica local. Cobre o contrato, o RBAC bilateral e os estados.

use App\Enums\TurnoStatus;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/** Turno num estado dado, com vaga geolocalizada (SP centro). */
function turnoEm(TurnoStatus $status): Turno
{
    $turno = Turno::factory()->status($status)->create();
    $turno->vaga->update(['lat' => -23.55, 'lng' => -46.63]);

    return $turno->fresh(['vaga', 'profissional', 'contratante']);
}

test('profissional lê o cronômetro com a âncora e a hora do servidor (CA-4)', function () {
    $turno = turnoEm(TurnoStatus::Ativo);

    $res = $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}/cronometro");

    $res->assertStatus(200)
        ->assertJsonStructure(['estado', 'iniciado_em', 'encerrado_em', 'servidor_agora', 'sou_profissional'])
        ->assertJsonPath('estado', 'ativo')
        ->assertJsonPath('iniciado_em', $turno->check_in_at->toIso8601String())
        ->assertJsonPath('encerrado_em', null)
        ->assertJsonPath('sou_profissional', true);

    // servidor_agora é um instante coerente (não nulo, parseável).
    expect($res->json('servidor_agora'))->not->toBeNull();
});

test('contratante lê o mesmo cronômetro (sincronia bilateral ancora no mesmo iniciado_em)', function () {
    $turno = turnoEm(TurnoStatus::Ativo);

    $res = $this->actingAs($turno->contratante)->getJson("/api/turnos/{$turno->id}/cronometro");

    $res->assertStatus(200)
        ->assertJsonPath('iniciado_em', $turno->check_in_at->toIso8601String())
        // Contratante NÃO é o profissional → não captura o geofencing (PDR-008).
        ->assertJsonPath('sou_profissional', false);
});

test('turno finalizado expõe encerrado_em (cronômetro parou)', function () {
    $turno = turnoEm(TurnoStatus::Finalizado);

    $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}/cronometro")
        ->assertStatus(200)
        ->assertJsonPath('estado', 'finalizado')
        ->assertJsonPath('iniciado_em', $turno->check_in_at->toIso8601String())
        ->assertJsonPath('encerrado_em', $turno->check_out_at->toIso8601String());
});

test('antes do check-in (confirmado) a âncora ainda é null', function () {
    $turno = turnoEm(TurnoStatus::Confirmado);

    $this->actingAs($turno->profissional)->getJson("/api/turnos/{$turno->id}/cronometro")
        ->assertStatus(200)
        ->assertJsonPath('estado', 'confirmado')
        ->assertJsonPath('iniciado_em', null);
});

test('terceiro (nem profissional nem contratante) → 404', function () {
    $turno = turnoEm(TurnoStatus::Ativo);
    $estranho = User::factory()->profissional()->ativo()->create();

    $this->actingAs($estranho)->getJson("/api/turnos/{$turno->id}/cronometro")->assertStatus(404);
});

test('não autenticado → 401', function () {
    $turno = turnoEm(TurnoStatus::Ativo);

    $this->getJson("/api/turnos/{$turno->id}/cronometro")->assertStatus(401);
});

test('turno inexistente → 404', function () {
    $turno = turnoEm(TurnoStatus::Ativo);

    $this->actingAs($turno->profissional)
        ->getJson('/api/turnos/00000000-0000-0000-0000-000000000000/cronometro')
        ->assertStatus(404);
});
