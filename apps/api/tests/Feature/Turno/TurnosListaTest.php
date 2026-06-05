<?php

// STORY-059 — GET /api/profissional/turnos e GET /api/contratante/turnos: listas agrupadas por
// estado na ordem do ciclo de vida (SCREEN-059 §4.1), grupo vazio omitido, ordenação interna por
// grupo (CA-1/CA-2), RBAC fail-secure (CA-5) e visibilidade financeira por papel (PDR-004).

use App\Enums\TurnoStatus;
use App\Models\ContratanteProfile;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

// ---------------------------------------------------------------- profissional (CA-1)

test('profissional vê os próprios turnos agrupados na ordem do ciclo de vida', function () {
    $pro = User::factory()->profissional()->ativo()->create();

    Turno::factory()->status(TurnoStatus::Finalizado)->create(['profissional_id' => $pro->id]);
    Turno::factory()->status(TurnoStatus::Confirmado)->create(['profissional_id' => $pro->id]);
    Turno::factory()->status(TurnoStatus::Ativo)->create(['profissional_id' => $pro->id]);

    $grupos = $this->actingAs($pro)->getJson('/api/profissional/turnos')
        ->assertStatus(200)
        ->json('grupos');

    // Ordem fixa das seções; grupos sem turno (aguardando_*, em_disputa, encerrado) omitidos.
    expect(array_column($grupos, 'grupo'))->toBe(['confirmado', 'ativo', 'finalizado']);
});

test('item do profissional traz função, datas, estado, valor e estabelecimento', function () {
    $pro = User::factory()->profissional()->ativo()->create();
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create(['profissional_id' => $pro->id]);

    $resposta = $this->actingAs($pro)->getJson('/api/profissional/turnos')->assertStatus(200);

    $item = $resposta->json('grupos.0.turnos.0');
    expect($item['id'])->toBe($turno->id)
        ->and($item['funcao'])->toBe($turno->vaga->funcao->nome)
        ->and($item['estado'])->toBe('confirmado')
        ->and($item['valor'])->toEqual((float) $turno->valor)
        ->and($item['data_inicio'])->toBe($turno->data_inicio->toIso8601String())
        ->and($item['data_fim'])->toBe($turno->data_fim->toIso8601String())
        ->and($item)->toHaveKey('estabelecimento')
        // PDR-004: o profissional NUNCA vê a taxa/total do contratante.
        ->and($item)->not->toHaveKeys(['taxa_turni', 'total_contratante']);
});

test('estabelecimento usa apelido quando houver, senão o nome (regra da STORY-049)', function () {
    $pro = User::factory()->profissional()->ativo()->create();
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create(['profissional_id' => $pro->id]);

    ContratanteProfile::create([
        'user_id' => $turno->contratante_id,
        'nome_estabelecimento' => 'Restaurante Vela Ltda',
        'apelido_estabelecimento' => 'Vela Bar',
    ]);

    $this->actingAs($pro)->getJson('/api/profissional/turnos')
        ->assertJsonPath('grupos.0.turnos.0.estabelecimento.nome', 'Vela Bar');
});

test('contratante sem profile: estabelecimento cai no name do usuário (convenção MVP)', function () {
    $pro = User::factory()->profissional()->ativo()->create();
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create(['profissional_id' => $pro->id]);

    $this->actingAs($pro)->getJson('/api/profissional/turnos')
        ->assertJsonPath('grupos.0.turnos.0.estabelecimento.nome', $turno->contratante->name);
});

test('grupos futuros ordenam por data_inicio asc; passados por data_fim desc (CA-1)', function () {
    $pro = User::factory()->profissional()->ativo()->create();

    $confirmadoLonge = Turno::factory()->status(TurnoStatus::Confirmado)
        ->create(['profissional_id' => $pro->id, 'data_inicio' => now()->addDays(10), 'data_fim' => now()->addDays(10)->addHours(6)]);
    $confirmadoPerto = Turno::factory()->status(TurnoStatus::Confirmado)
        ->create(['profissional_id' => $pro->id, 'data_inicio' => now()->addDay(), 'data_fim' => now()->addDay()->addHours(6)]);
    $finalizadoAntigo = Turno::factory()->status(TurnoStatus::Finalizado)
        ->create(['profissional_id' => $pro->id, 'data_inicio' => now()->subDays(9), 'data_fim' => now()->subDays(9)->addHours(6)]);
    $finalizadoRecente = Turno::factory()->status(TurnoStatus::Finalizado)
        ->create(['profissional_id' => $pro->id, 'data_inicio' => now()->subDays(2), 'data_fim' => now()->subDays(2)->addHours(6)]);

    $grupos = $this->actingAs($pro)->getJson('/api/profissional/turnos')->json('grupos');

    expect(array_column($grupos[0]['turnos'], 'id'))->toBe([$confirmadoPerto->id, $confirmadoLonge->id])
        ->and(array_column($grupos[1]['turnos'], 'id'))->toBe([$finalizadoRecente->id, $finalizadoAntigo->id]);
});

test('finalizado_ajustado entra no grupo finalizado; terminais entram em encerrado', function () {
    $pro = User::factory()->profissional()->ativo()->create();

    Turno::factory()->status(TurnoStatus::FinalizadoAjustado)->create(['profissional_id' => $pro->id]);
    Turno::factory()->status(TurnoStatus::CanceladoEmp)->create(['profissional_id' => $pro->id]);
    Turno::factory()->status(TurnoStatus::NoShowPro)->create(['profissional_id' => $pro->id]);
    Turno::factory()->status(TurnoStatus::DisputaResolvidaSemPagamento)->create(['profissional_id' => $pro->id]);

    $grupos = $this->actingAs($pro)->getJson('/api/profissional/turnos')->json('grupos');

    expect(array_column($grupos, 'grupo'))->toBe(['finalizado', 'encerrado'])
        ->and($grupos[0]['turnos'])->toHaveCount(1)
        ->and($grupos[0]['turnos'][0]['estado'])->toBe('finalizado_ajustado')
        ->and($grupos[1]['turnos'])->toHaveCount(3);
});

test('em_disputa é seção própria (decisão PO 2026-06-05)', function () {
    $pro = User::factory()->profissional()->ativo()->create();
    Turno::factory()->status(TurnoStatus::EmDisputa)->create(['profissional_id' => $pro->id]);

    $grupos = $this->actingAs($pro)->getJson('/api/profissional/turnos')->json('grupos');

    expect(array_column($grupos, 'grupo'))->toBe(['em_disputa']);
});

test('profissional sem turnos recebe grupos vazios', function () {
    $pro = User::factory()->profissional()->ativo()->create();

    $this->actingAs($pro)->getJson('/api/profissional/turnos')
        ->assertStatus(200)
        ->assertExactJson(['grupos' => []]);
});

test('turno de outro profissional não vaza', function () {
    $pro = User::factory()->profissional()->ativo()->create();
    Turno::factory()->status(TurnoStatus::Confirmado)->create(); // de outro profissional

    $this->actingAs($pro)->getJson('/api/profissional/turnos')
        ->assertStatus(200)
        ->assertExactJson(['grupos' => []]);
});

// ---------------------------------------------------------------- contratante (CA-2)

test('contratante vê os turnos das próprias vagas com total e nome do profissional', function () {
    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create();
    $contratante = $turno->fresh()->contratante;

    $item = $this->actingAs($contratante)->getJson('/api/contratante/turnos')
        ->assertStatus(200)
        ->json('grupos.0.turnos.0');

    expect($item['id'])->toBe($turno->id)
        ->and($item['total_contratante'])->toEqual((float) $turno->total_contratante)
        ->and($item['profissional']['nome'])->toBe($turno->profissional->name)
        // Espelho do PDR-004: o card do contratante usa o total; `valor` cru não é exposto aqui.
        ->and($item)->not->toHaveKey('valor')
        ->and($item)->not->toHaveKey('estabelecimento');
});

test('turno de outro contratante não vaza', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    Turno::factory()->status(TurnoStatus::Confirmado)->create(); // de outro contratante

    $this->actingAs($contratante)->getJson('/api/contratante/turnos')
        ->assertStatus(200)
        ->assertExactJson(['grupos' => []]);
});

// ---------------------------------------------------------------- RBAC fail-secure (CA-5)

test('contratante em /profissional/turnos → 403', function () {
    $contratante = User::factory()->contratante()->ativo()->create();

    $this->actingAs($contratante)->getJson('/api/profissional/turnos')->assertStatus(403);
});

test('profissional em /contratante/turnos → 403', function () {
    $pro = User::factory()->profissional()->ativo()->create();

    $this->actingAs($pro)->getJson('/api/contratante/turnos')->assertStatus(403);
});

test('não autenticado → 401 nas duas rotas', function () {
    $this->getJson('/api/profissional/turnos')->assertStatus(401);
    $this->getJson('/api/contratante/turnos')->assertStatus(401);
});
