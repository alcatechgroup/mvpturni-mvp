<?php

// STORY-047 — GET /api/vagas/minhas: lista das vagas do contratante autenticado.
// Cobre CA-1 (RBAC: contratante só vê próprias; profissional 403) e CA-2 (shape do
// card: função, data/hora, valor, posições preenchidas/total, estado, candidatos
// pendentes). Filtro é client-side (a estória não pede paginação) — o endpoint
// devolve todas as vagas do contratante.

use App\Enums\CandidaturaEstado;
use App\Models\Candidatura;
use App\Models\Funcao;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/** Cria um contratante ativo dono de uma vaga (estado configurável). */
function vagaDoContratante(User $contratante, array $over = []): Vaga
{
    return Vaga::factory()->create(array_merge([
        'contratante_id' => $contratante->id,
    ], $over));
}

// ───────────────────────── CA-2 — caminho feliz (shape do card) ─────────────────────────

test('contratante vê suas vagas com o shape do card (CA-2)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $funcao = Funcao::factory()->create(['nome' => 'Garçom']);
    vagaDoContratante($contratante, [
        'funcao_id' => $funcao->id,
        'valor' => 150.00,
        'posicoes' => 3,
        'posicoes_preenchidas' => 1,
    ]);

    $res = $this->actingAs($contratante)->getJson('/api/vagas/minhas');

    $res->assertStatus(200)
        ->assertJsonStructure(['data' => [[
            'id', 'funcao', 'funcao_id', 'data_inicio', 'data_fim',
            'valor', 'posicoes', 'posicoes_preenchidas', 'estado', 'candidatos_pendentes',
        ]]])
        ->assertJsonPath('data.0.funcao', 'Garçom')
        ->assertJsonPath('data.0.valor', 150)
        ->assertJsonPath('data.0.posicoes', 3)
        ->assertJsonPath('data.0.posicoes_preenchidas', 1)
        ->assertJsonPath('data.0.estado', 'aberta');
});

test('candidatos_pendentes conta só candidaturas pendentes (CA-2)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $vaga = vagaDoContratante($contratante);

    Candidatura::factory()->count(2)->create(['vaga_id' => $vaga->id, 'estado' => CandidaturaEstado::Pendente]);
    Candidatura::factory()->create(['vaga_id' => $vaga->id, 'estado' => CandidaturaEstado::Aprovada]);
    Candidatura::factory()->create(['vaga_id' => $vaga->id, 'estado' => CandidaturaEstado::Retirada]);

    $this->actingAs($contratante)->getJson('/api/vagas/minhas')
        ->assertStatus(200)
        ->assertJsonPath('data.0.candidatos_pendentes', 2);
});

test('vaga sem candidaturas → candidatos_pendentes 0 (borda)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    vagaDoContratante($contratante);

    $this->actingAs($contratante)->getJson('/api/vagas/minhas')
        ->assertStatus(200)
        ->assertJsonPath('data.0.candidatos_pendentes', 0);
});

test('lista inclui vagas em todos os estados (filtro é client-side — CA-3)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    vagaDoContratante($contratante); // aberta (default)
    Vaga::factory()->fechada()->create(['contratante_id' => $contratante->id]);
    Vaga::factory()->cancelada()->create(['contratante_id' => $contratante->id]);

    $res = $this->actingAs($contratante)->getJson('/api/vagas/minhas')->assertStatus(200);

    $estados = collect($res->json('data'))->pluck('estado')->sort()->values()->all();
    expect($estados)->toEqual(['aberta', 'cancelada', 'fechada']);
});

// ───────────────────────── CA-1 — RBAC / escopo ─────────────────────────

test('contratante NÃO vê vagas de outro contratante (CA-1)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $outro = User::factory()->contratante()->ativo()->create();
    vagaDoContratante($outro);

    $this->actingAs($contratante)->getJson('/api/vagas/minhas')
        ->assertStatus(200)
        ->assertJsonCount(0, 'data');
});

test('profissional recebe 403 ao listar vagas do contratante (CA-1)', function () {
    $prof = User::factory()->profissional()->ativo()->create();

    $this->actingAs($prof)->getJson('/api/vagas/minhas')->assertStatus(403);
});

test('não autenticado recebe 401 (exceção)', function () {
    $this->getJson('/api/vagas/minhas')->assertStatus(401);
});

// ───────────────────────── borda — lista vazia (CA-7) ─────────────────────────

test('contratante sem vagas → 200 com data vazia (CA-7)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();

    $this->actingAs($contratante)->getJson('/api/vagas/minhas')
        ->assertStatus(200)
        ->assertJsonCount(0, 'data');
});
