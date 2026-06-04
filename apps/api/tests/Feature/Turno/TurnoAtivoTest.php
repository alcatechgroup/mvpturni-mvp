<?php

// STORY-057 / ADR-017 — GET /api/turnos/meu-ativo: atalho de navegação ao turno em andamento do
// usuário (qualquer lado). Devolve { turno_id } ou null.

use App\Enums\TurnoStatus;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('profissional vê o id do seu turno ativo', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create();

    $this->actingAs($turno->fresh()->profissional)->getJson('/api/turnos/meu-ativo')
        ->assertStatus(200)
        ->assertJsonPath('turno_id', $turno->id);
});

test('contratante vê o id do seu turno ativo', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create();

    $this->actingAs($turno->fresh()->contratante)->getJson('/api/turnos/meu-ativo')
        ->assertStatus(200)
        ->assertJsonPath('turno_id', $turno->id);
});

test('sem turno ativo → turno_id null', function () {
    // Turno confirmado (não-ativo) não conta.
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();

    $this->actingAs($turno->fresh()->profissional)->getJson('/api/turnos/meu-ativo')
        ->assertStatus(200)
        ->assertJsonPath('turno_id', null);
});

test('turno de outro usuário não vaza', function () {
    Turno::factory()->status(TurnoStatus::Ativo)->create();
    $estranho = User::factory()->profissional()->ativo()->create();

    $this->actingAs($estranho)->getJson('/api/turnos/meu-ativo')
        ->assertStatus(200)
        ->assertJsonPath('turno_id', null);
});

test('não autenticado → 401', function () {
    $this->getJson('/api/turnos/meu-ativo')->assertStatus(401);
});
