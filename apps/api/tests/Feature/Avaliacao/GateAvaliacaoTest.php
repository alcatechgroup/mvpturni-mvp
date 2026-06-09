<?php

// STORY-086 / ADR-019 D5 / PDR-005 — gate bloqueante de avaliação pendente nos DOIS papéis.
// Profissional não candidata e contratante não publica enquanto houver turno finalizado por
// avaliar. Pendência derivada do estado (ADR-019 D2). Cobre: bloqueia (2 papéis) com turno_id,
// libera sem pendência / após avaliar, escolhe o turno mais antigo, não vaza entre papéis e é
// fail-secure (erro de consulta → bloqueia).

use App\Domain\Avaliacao\AvaliacoesPendentesContratante;
use App\Enums\TurnoStatus;
use App\Enums\VagaEstado;
use App\Models\Avaliacao;
use App\Models\Candidatura;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

// ─────────────────────────── helpers (nomes únicos no suite global) ───────────────────────────

function gateFuncao(): Funcao
{
    return Funcao::firstOrCreate(['slug' => 'garcom'], ['nome' => 'Garçom', 'ativo' => true]);
}

function gateProfissional(): User
{
    $user = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->create(['user_id' => $user->id, 'funcao_id' => gateFuncao()->id]);

    return $user;
}

function gateContratante(): User
{
    $user = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::create([
        'user_id' => $user->id,
        'nome_estabelecimento' => 'Bar do Gate',
        'tipo_operacao' => 'bar',
        'cidade' => 'São Paulo',
        'uf' => 'SP',
    ]);

    return $user;
}

/** Vaga aberta futura para o profissional se candidatar (com versão 1). */
function gateVagaAberta(): Vaga
{
    $vaga = Vaga::factory()->create([
        'contratante_id' => gateContratante()->id,
        'funcao_id' => gateFuncao()->id,
        'estado' => VagaEstado::Aberta,
        'data_inicio' => now()->addDays(4)->setTime(18, 0),
        'data_fim' => now()->addDays(4)->setTime(23, 0),
        'valor' => 150.00,
        'cidade' => 'São Paulo', 'lat' => -23.55, 'lng' => -46.63,
    ]);
    VagaVersao::create([
        'vaga_id' => $vaga->id, 'versao' => $vaga->versao_atual,
        'snapshot' => ['funcao_id' => $vaga->funcao_id], 'editado_por' => $vaga->contratante_id,
    ]);

    return $vaga;
}

/** Turno finalizado (no passado) com o papel dado fixado. */
function gateTurnoFinalizado(array $over = [], string $fim = '-2 days'): Turno
{
    $fimAt = now()->parse($fim);

    return Turno::factory()->status(TurnoStatus::Finalizado)->create(array_merge([
        'data_inicio' => $fimAt->copy()->subHours(6),
        'data_fim' => $fimAt,
    ], $over));
}

/** @return array<string,mixed> */
function gatePayloadVaga(): array
{
    return [
        'funcao_id' => gateFuncao()->id,
        'data_inicio' => now()->addDays(5)->setTime(18, 0)->toIso8601String(),
        'data_fim' => now()->addDays(5)->setTime(23, 0)->toIso8601String(),
        'valor' => 150.00,
        'posicoes' => 1,
        'observacoes' => null,
    ];
}

// ─────────────────────────── CA-1 — profissional bloqueado ao candidatar ───────────────────────────

test('CA-1: profissional com avaliação pendente é bloqueado ao candidatar → 422 + turno_id', function () {
    $prof = gateProfissional();
    $turno = gateTurnoFinalizado(['profissional_id' => $prof->id]);
    $vaga = gateVagaAberta();

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")
        ->assertStatus(422)
        ->assertJsonPath('erro', 'gate_avaliacao')
        ->assertJsonPath('mensagem', 'Avalie seu último turno para se candidatar.')
        ->assertJsonPath('detalhe.turno_id', $turno->id);

    // Nenhuma candidatura deste profissional nesta vaga (a do turno-fixture é de outro par).
    expect(Candidatura::where('profissional_id', $prof->id)->where('vaga_id', $vaga->id)->count())->toBe(0);
});

test('CA-1: profissional que JÁ avaliou o turno candidata normalmente → 201', function () {
    $prof = gateProfissional();
    $turno = gateTurnoFinalizado(['profissional_id' => $prof->id]);
    // O profissional já avaliou o contratante (direção dele) → sem pendência.
    Avaliacao::factory()->doProfissional()->paraTurno($turno)->create();
    $vaga = gateVagaAberta();

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")->assertStatus(201);
});

test('CA-1: turno_id no bloqueio é o turno pendente MAIS ANTIGO', function () {
    $prof = gateProfissional();
    $novo = gateTurnoFinalizado(['profissional_id' => $prof->id], '-1 day');
    $antigo = gateTurnoFinalizado(['profissional_id' => $prof->id], '-10 days');
    $vaga = gateVagaAberta();

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")
        ->assertStatus(422)
        ->assertJsonPath('detalhe.turno_id', $antigo->id);

    expect($novo->id)->not->toBe($antigo->id);
});

// ─────────────────────────── CA-2 — contratante bloqueado ao publicar ───────────────────────────

test('CA-2: contratante com avaliação pendente é bloqueado ao publicar → 422 + turno_id', function () {
    $contratante = gateContratante();
    $turno = gateTurnoFinalizado(['contratante_id' => $contratante->id, 'estabelecimento_id' => $contratante->id]);

    $this->actingAs($contratante)->postJson('/api/vagas', gatePayloadVaga())
        ->assertStatus(422)
        ->assertJsonPath('erro', 'gate_avaliacao')
        ->assertJsonPath('mensagem', 'Avalie seu último turno para publicar uma nova vaga.')
        ->assertJsonPath('detalhe.turno_id', $turno->id);

    // Fail-secure / sem regressão: este contratante não criou vaga (a vaga do turno-fixture é
    // de outro contratante aleatório do factory).
    expect(Vaga::where('contratante_id', $contratante->id)->count())->toBe(0);
});

test('CA-2: contratante que JÁ avaliou o turno publica normalmente → 201', function () {
    $contratante = gateContratante();
    $turno = gateTurnoFinalizado(['contratante_id' => $contratante->id, 'estabelecimento_id' => $contratante->id]);
    // Contratante já avaliou o profissional (direção dele) → sem pendência.
    Avaliacao::factory()->paraTurno($turno)->create();

    $this->actingAs($contratante)->postJson('/api/vagas', gatePayloadVaga())->assertStatus(201);
});

test('CA-2: turno_id no bloqueio da publicação é o turno pendente MAIS ANTIGO', function () {
    $contratante = gateContratante();
    gateTurnoFinalizado(['contratante_id' => $contratante->id, 'estabelecimento_id' => $contratante->id], '-1 day');
    $antigo = gateTurnoFinalizado(['contratante_id' => $contratante->id, 'estabelecimento_id' => $contratante->id], '-12 days');

    $this->actingAs($contratante)->postJson('/api/vagas', gatePayloadVaga())
        ->assertStatus(422)
        ->assertJsonPath('detalhe.turno_id', $antigo->id);
});

// ─────────────────────────── CA-3 — sem pendência, ações fluem (sem regressão) ───────────────────────────

test('CA-3: profissional sem pendência candidata normalmente → 201', function () {
    $prof = gateProfissional();
    $vaga = gateVagaAberta();

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")->assertStatus(201);
});

test('CA-3: contratante sem pendência publica normalmente → 201', function () {
    $contratante = gateContratante();

    $this->actingAs($contratante)->postJson('/api/vagas', gatePayloadVaga())
        ->assertStatus(201)
        ->assertJsonPath('estado', 'aberta');
});

test('CA-3/CA-4: estado finalizado_ajustado também conta como pendência (avaliável)', function () {
    $contratante = gateContratante();
    $turno = gateTurnoFinalizado([
        'contratante_id' => $contratante->id, 'estabelecimento_id' => $contratante->id,
        'status' => TurnoStatus::FinalizadoAjustado,
    ]);

    $this->actingAs($contratante)->postJson('/api/vagas', gatePayloadVaga())
        ->assertStatus(422)
        ->assertJsonPath('detalhe.turno_id', $turno->id);
});

// ─────────────────────────── CA-4 — sem vazamento entre papéis ───────────────────────────

test('CA-4: pendência como profissional NÃO bloqueia a publicação como contratante', function () {
    // Mesmo turno: o usuário é o contratante; um turno onde ele é PROFISSIONAL não bloqueia
    // a publicação (papéis e direções separados). Aqui o user publica e tem pendência só do
    // outro papel.
    $user = gateContratante();
    // Pendência apenas na ponta de profissional deste user (não deveria afetar publicar).
    gateTurnoFinalizado(['profissional_id' => $user->id]);

    $this->actingAs($user)->postJson('/api/vagas', gatePayloadVaga())->assertStatus(201);
});

test('CA-4: pendência de OUTRO contratante não bloqueia este contratante', function () {
    $contratante = gateContratante();
    $outro = gateContratante();
    gateTurnoFinalizado(['contratante_id' => $outro->id, 'estabelecimento_id' => $outro->id]);

    $this->actingAs($contratante)->postJson('/api/vagas', gatePayloadVaga())->assertStatus(201);
});

// ─────────────────────────── CA-4 — fail-secure (erro de consulta bloqueia) ───────────────────────────

test('CA-4: falha ao consultar pendência do contratante → bloqueia (fail-secure)', function () {
    $contratante = gateContratante();

    // Simula erro de infra na consulta de pendência: o gate deve BLOQUEAR, nunca liberar.
    $this->mock(AvaliacoesPendentesContratante::class)
        ->shouldReceive('para')->andThrow(new RuntimeException('db down'));

    $this->actingAs($contratante)->postJson('/api/vagas', gatePayloadVaga())
        ->assertStatus(422)
        ->assertJsonPath('erro', 'gate_avaliacao')
        ->assertJsonPath('detalhe.turno_id', null);

    $this->assertDatabaseCount('vagas', 0);
});

// ─────────────────────────── contrato do endpoint de leitura (contratante) ───────────────────────────

test('endpoint pendentes-do-contratante reflete a pendência derivada (pending + turnos)', function () {
    $contratante = gateContratante();
    $turno = gateTurnoFinalizado(['contratante_id' => $contratante->id, 'estabelecimento_id' => $contratante->id]);

    $res = $this->actingAs($contratante)->getJson('/api/avaliacoes/pendentes-do-contratante');

    $res->assertOk()
        ->assertJsonPath('pending', 1)
        ->assertJsonPath('turnos.0.turno_id', $turno->id)
        ->assertJsonStructure(['pending', 'turnos' => [['turno_id', 'data_fim']]]);
});
