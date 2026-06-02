<?php

// STORY-046 CA-5 — gate PDR-005: GET /api/avaliacoes/pendentes-do-contratante.
// Stub-honesto (decisão do PO, 2026-06-02): turnos/avaliações são do EPIC-003; até lá
// o endpoint responde {pending:0, turnos:[]} via service isolado. O gate da UI é
// exercitado no front com pending>0 mockado. Aqui garantimos o contrato + o RBAC.

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('contratante ativo recebe contrato {pending:0, turnos:[]} (CA-5 stub)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();

    $res = $this->actingAs($contratante)->getJson('/api/avaliacoes/pendentes-do-contratante');

    $res->assertOk()
        ->assertJsonStructure(['pending', 'turnos'])
        ->assertJsonPath('pending', 0)
        ->assertJsonPath('turnos', []);

    expect($res->json('pending'))->toBeInt();
});

test('profissional recebe 403 no gate do contratante (CA-1)', function () {
    $prof = User::factory()->profissional()->ativo()->create();

    $this->actingAs($prof)->getJson('/api/avaliacoes/pendentes-do-contratante')->assertStatus(403);
});

test('não autenticado recebe 401 (exceção)', function () {
    $this->getJson('/api/avaliacoes/pendentes-do-contratante')->assertStatus(401);
});
