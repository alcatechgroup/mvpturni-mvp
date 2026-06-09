<?php

// STORY-050 — POST /api/vagas/{vaga}/candidaturas + DELETE /api/candidaturas/{candidatura}.
// Cobre CA-1 (cria pendente + contrato/score_no_momento), CA-2 (gate avaliação PDR-005),
// CA-3 (conflito de horário), CA-4 (habitualidade PF bloqueia / MEI-PJ alerta), CA-5
// (vaga fechada), CA-6 (idempotência 409 + reativação após retirada), CA-7 (audit log +
// evento de domínio + telemetria) e CA-8 (retirada voluntária + 409 fora de pendente + 404
// p/ não-dono). RBAC (profissional/contratante) também aqui.

use App\Domain\Avaliacao\AvaliacoesPendentesProfissional;
use App\Enums\CandidaturaEstado;
use App\Enums\TurnoStatus;
use App\Enums\VagaEstado;
use App\Events\CandidaturaEnviada;
use App\Models\AuditLog;
use App\Models\Candidatura;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Carbon\CarbonInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;

uses(RefreshDatabase::class);

/** Profissional ativo com perfil (geo SP + raio amplo). `tipo` sobrescreve PF/MEI/PJ. */
function profCand(array $perfil = []): User
{
    $user = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->create(array_merge(['user_id' => $user->id], $perfil));

    return $user;
}

/** Contratante ativo com estabelecimento (o modelo não tem factory). */
function contratanteCand(array $perfil = []): User
{
    $contratante = User::factory()->contratante()->ativo()->create();
    $cnpj = (string) fake()->unique()->numerify('##############');
    ContratanteProfile::create(array_merge([
        'user_id' => $contratante->id,
        'cnpj_encrypted' => $cnpj,
        'cnpj_hash' => hash_hmac('sha256', $cnpj, (string) config('app.key')),
        'nome_estabelecimento' => 'Bar do Zé Ltda',
        'apelido_estabelecimento' => 'Bar do Zé',
        'cidade' => 'São Paulo',
    ], $perfil));

    return $contratante;
}

/** Vaga aberta futura na Grande SP. */
function vagaCand(string $funcaoId, array $over = []): Vaga
{
    $contratanteId = $over['contratante_id'] ?? contratanteCand()->id;
    unset($over['contratante_id']);

    $vaga = Vaga::factory()->create(array_merge([
        'contratante_id' => $contratanteId,
        'funcao_id' => $funcaoId,
        'estado' => VagaEstado::Aberta,
        'data_inicio' => now()->addDays(3)->setTime(18, 0),
        'data_fim' => now()->addDays(3)->setTime(23, 0),
        'valor' => 150.00,
        'cidade' => 'São Paulo',
        'lat' => -23.55, 'lng' => -46.63,
    ], $over));

    // Versão 1 (snapshot inicial) — o serviço liga a candidatura à versão vigente (PDR-009).
    VagaVersao::create([
        'vaga_id' => $vaga->id,
        'versao' => $vaga->versao_atual,
        'snapshot' => ['funcao_id' => $vaga->funcao_id],
        'editado_por' => $vaga->contratante_id,
    ]);

    return $vaga;
}

// ───────────────────────── CA-1 — criação + contrato ─────────────────────────

test('candidatura cria pendente e devolve o contrato com score_no_momento (CA-1)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id);

    $res = $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas");

    $res->assertStatus(201)
        ->assertJsonStructure(['id', 'estado', 'score_no_momento', 'candidatou_em', 'alerta'])
        ->assertJsonPath('estado', 'pendente')
        ->assertJsonPath('alerta', false);

    expect($res->json('score_no_momento'))->toBeGreaterThan(0);

    $this->assertDatabaseHas('candidaturas', [
        'vaga_id' => $vaga->id,
        'profissional_id' => $prof->id,
        'estado' => 'pendente',
    ]);

    $candidatura = Candidatura::first();
    expect($candidatura->score_no_momento)->toBe($res->json('score_no_momento'));
    expect($candidatura->vaga_versao_id)->not->toBeNull();
});

test('contratante recebe 403 ao candidatar (RBAC — CA-1)', function () {
    $funcao = Funcao::factory()->create();
    $vaga = vagaCand($funcao->id);
    $contratante = User::factory()->contratante()->ativo()->create();

    $this->actingAs($contratante)->postJson("/api/vagas/{$vaga->id}/candidaturas")->assertStatus(403);
});

test('não autenticado recebe 401 ao candidatar', function () {
    $funcao = Funcao::factory()->create();
    $vaga = vagaCand($funcao->id);

    $this->postJson("/api/vagas/{$vaga->id}/candidaturas")->assertStatus(401);
});

test('vaga inexistente → 404', function () {
    $prof = profCand();

    $this->actingAs($prof)->postJson('/api/vagas/00000000-0000-0000-0000-000000000000/candidaturas')->assertStatus(404);
});

// ───────────────────────── CA-5 — pré-condições (vaga fechada) ─────────────────────────

test('vaga fechada → 422 vaga_fechada (CA-5)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id, ['estado' => VagaEstado::Fechada]);

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")
        ->assertStatus(422)
        ->assertJsonPath('erro', 'vaga_fechada')
        ->assertJsonPath('mensagem', 'Esta vaga não está mais aberta para candidaturas.');
});

test('vaga no passado → 422 vaga_fechada (CA-5)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id, [
        'data_inicio' => now()->subDay()->setTime(18, 0),
        'data_fim' => now()->subDay()->setTime(23, 0),
    ]);

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")
        ->assertStatus(422)
        ->assertJsonPath('erro', 'vaga_fechada');
});

// ───────────────────────── CA-6 — idempotência ─────────────────────────

test('candidatar 2x na mesma vaga → 409 ja_candidatou (CA-6)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id);

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")->assertStatus(201);

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")
        ->assertStatus(409)
        ->assertJsonPath('erro', 'ja_candidatou')
        ->assertJsonStructure(['detalhe' => ['candidatura' => ['id', 'estado', 'criada_em']]]);

    expect(Candidatura::where('vaga_id', $vaga->id)->count())->toBe(1);
});

test('candidatar de novo após retirada reativa a candidatura (SCREEN-050 §4.9)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id);

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")->assertStatus(201);
    $candidatura = Candidatura::first();
    $this->actingAs($prof)->deleteJson("/api/candidaturas/{$candidatura->id}")->assertStatus(200);

    // Re-candidatar: reusa a mesma linha (UNIQUE vaga+profissional), volta a pendente.
    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")->assertStatus(201);

    expect(Candidatura::where('vaga_id', $vaga->id)->count())->toBe(1);
    expect(Candidatura::first()->estado)->toBe(CandidaturaEstado::Pendente);
    expect(Candidatura::first()->retirada_em)->toBeNull();
});

// ───────────────────────── CA-2 — gate avaliação (PDR-005) ─────────────────────────

test('gate avaliação ativo → 422 gate_avaliacao + detalhe.turno_id (CA-2)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id);

    // STORY-086: o gate consome a pendência derivada (turnoPendente) e devolve o turno por
    // avaliar no payload (deep-link). Mockamos o turno pendente para isolar do schema de turnos.
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)
        ->create(['profissional_id' => $prof->id]);

    $this->mock(AvaliacoesPendentesProfissional::class)
        ->shouldReceive('turnoPendente')->andReturn($turno);

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")
        ->assertStatus(422)
        ->assertJsonPath('erro', 'gate_avaliacao')
        ->assertJsonPath('mensagem', 'Avalie seu último turno para se candidatar.')
        ->assertJsonPath('detalhe.turno_id', $turno->id);

    // Nenhuma candidatura deste profissional nesta vaga (a do turno-fixture é de outro par).
    expect(Candidatura::where('profissional_id', $prof->id)->where('vaga_id', $vaga->id)->count())->toBe(0);
});

// ───────────────────────── CA-3 — conflito de horário ─────────────────────────

test('conflito de horário → 422 conflito_horario + detalhe.conflito_com (CA-3)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);

    // Já candidatado numa vaga das 18:00–23:00.
    $vagaA = vagaCand($funcao->id);
    Candidatura::factory()->create([
        'vaga_id' => $vagaA->id, 'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Pendente,
    ]);

    // Nova vaga sobrepõe (20:00–01:00) no mesmo dia.
    $vagaB = vagaCand($funcao->id, [
        'data_inicio' => now()->addDays(3)->setTime(20, 0),
        'data_fim' => now()->addDays(4)->setTime(1, 0),
    ]);

    $this->actingAs($prof)->postJson("/api/vagas/{$vagaB->id}/candidaturas")
        ->assertStatus(422)
        ->assertJsonPath('erro', 'conflito_horario')
        ->assertJsonPath('detalhe.conflito_com.tipo', 'candidatura')
        ->assertJsonPath('detalhe.conflito_com.vaga_id', $vagaA->id)
        ->assertJsonStructure(['detalhe' => ['conflito_com' => [
            'tipo', 'id', 'vaga_id', 'funcao', 'estabelecimento', 'data_inicio', 'data_fim',
        ]]]);
});

test('sem sobreposição de horário → candidatura criada (CA-3)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);

    $vagaA = vagaCand($funcao->id); // dia +3 18:00–23:00
    Candidatura::factory()->create([
        'vaga_id' => $vagaA->id, 'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Pendente,
    ]);

    // Outro dia, sem sobreposição.
    $vagaB = vagaCand($funcao->id, [
        'data_inicio' => now()->addDays(5)->setTime(18, 0),
        'data_fim' => now()->addDays(5)->setTime(23, 0),
    ]);

    $this->actingAs($prof)->postJson("/api/vagas/{$vagaB->id}/candidaturas")->assertStatus(201);
});

// ───────────────────────── CA-4 — habitualidade (PDR-002) ─────────────────────────

/** Cria duas alocações pendentes do prof no estabelecimento $contratante, na semana de $base. */
function duasAlocacoesNaSemana(User $prof, User $contratante, string $funcaoId): void
{
    foreach ([0, 1] as $offset) {
        $dia = now()->addWeek()->startOfWeek(CarbonInterface::MONDAY)->addDays($offset)->setTime(18, 0);
        $vaga = vagaCand($funcaoId, [
            'contratante_id' => $contratante->id,
            'data_inicio' => $dia, 'data_fim' => (clone $dia)->setTime(22, 0),
        ]);
        Candidatura::factory()->create([
            'vaga_id' => $vaga->id, 'profissional_id' => $prof->id,
            'estado' => CandidaturaEstado::Pendente,
        ]);
    }
}

test('PF na 3ª alocação na semana no mesmo local → 422 habitualidade_bloqueio (CA-4)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id, 'tipo_pessoa' => 'PF']);
    $contratante = contratanteCand();
    duasAlocacoesNaSemana($prof, $contratante, $funcao->id);

    // 3ª vaga: mesmo local, mesma semana, dia diferente (sem conflito de horário).
    $alvoDia = now()->addWeek()->startOfWeek(CarbonInterface::MONDAY)->addDays(3)->setTime(18, 0);
    $alvo = vagaCand($funcao->id, [
        'contratante_id' => $contratante->id,
        'data_inicio' => $alvoDia, 'data_fim' => (clone $alvoDia)->setTime(22, 0),
    ]);

    $this->actingAs($prof)->postJson("/api/vagas/{$alvo->id}/candidaturas")
        ->assertStatus(422)
        ->assertJsonPath('erro', 'habitualidade_bloqueio')
        ->assertJsonPath('mensagem', 'Você já tem 2 turnos nesta semana neste estabelecimento.');
});

test('MEI na 3ª alocação → 201 com alerta, sem bloqueio (CA-4)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id, 'tipo_pessoa' => 'MEI']);
    $contratante = contratanteCand();
    duasAlocacoesNaSemana($prof, $contratante, $funcao->id);

    $alvoDia = now()->addWeek()->startOfWeek(CarbonInterface::MONDAY)->addDays(3)->setTime(18, 0);
    $alvo = vagaCand($funcao->id, [
        'contratante_id' => $contratante->id,
        'data_inicio' => $alvoDia, 'data_fim' => (clone $alvoDia)->setTime(22, 0),
    ]);

    $this->actingAs($prof)->postJson("/api/vagas/{$alvo->id}/candidaturas")
        ->assertStatus(201)
        ->assertJsonPath('alerta', true);
});

test('alocações em estabelecimento diferente não contam para habitualidade (CA-4)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id, 'tipo_pessoa' => 'PF']);
    $outro = contratanteCand();
    duasAlocacoesNaSemana($prof, $outro, $funcao->id);

    // Alvo num contratante DIFERENTE → contagem zera p/ esse local.
    $alvoDia = now()->addWeek()->startOfWeek(CarbonInterface::MONDAY)->addDays(3)->setTime(18, 0);
    $alvo = vagaCand($funcao->id, [
        'data_inicio' => $alvoDia, 'data_fim' => (clone $alvoDia)->setTime(22, 0),
    ]);

    $this->actingAs($prof)->postJson("/api/vagas/{$alvo->id}/candidaturas")->assertStatus(201);
});

test('alocações em outra semana não contam para habitualidade (CA-4)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id, 'tipo_pessoa' => 'PF']);
    $contratante = contratanteCand();
    duasAlocacoesNaSemana($prof, $contratante, $funcao->id);

    // Alvo no MESMO local, porém duas semanas à frente (outra semana corrida).
    $alvoDia = now()->addWeeks(3)->startOfWeek(CarbonInterface::MONDAY)->addDays(3)->setTime(18, 0);
    $alvo = vagaCand($funcao->id, [
        'contratante_id' => $contratante->id,
        'data_inicio' => $alvoDia, 'data_fim' => (clone $alvoDia)->setTime(22, 0),
    ]);

    $this->actingAs($prof)->postJson("/api/vagas/{$alvo->id}/candidaturas")->assertStatus(201);
});

// ───────────────────────── CA-7 — audit log + evento + telemetria ─────────────────────────

test('sucesso registra audit log candidatura.criada e dispara CandidaturaEnviada (CA-7)', function () {
    Event::fake([CandidaturaEnviada::class]);

    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id);

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")->assertStatus(201);

    $candidatura = Candidatura::first();
    $this->assertDatabaseHas('audit_logs', [
        'actor_id' => $prof->id,
        'action' => 'candidatura.criada',
        'target_type' => 'Candidatura',
        'target_id' => $candidatura->id,
    ]);

    Event::assertDispatched(CandidaturaEnviada::class, fn ($e) => $e->candidatura->id === $candidatura->id);
});

test('gate bloqueado não cria audit log nem candidatura (CA-7)', function () {
    Event::fake([CandidaturaEnviada::class]);

    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id, ['estado' => VagaEstado::Cancelada]);

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")->assertStatus(422);

    expect(AuditLog::where('action', 'candidatura.criada')->count())->toBe(0);
    Event::assertNotDispatched(CandidaturaEnviada::class);
});

// ───────────────────────── CA-8 — retirada voluntária ─────────────────────────

test('dono retira candidatura pendente → 200 estado retirada (CA-8)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id);
    $candidatura = Candidatura::factory()->create([
        'vaga_id' => $vaga->id, 'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Pendente,
    ]);

    $this->actingAs($prof)->deleteJson("/api/candidaturas/{$candidatura->id}")
        ->assertStatus(200)
        ->assertJsonPath('estado', 'retirada');

    expect($candidatura->fresh()->estado)->toBe(CandidaturaEstado::Retirada);
    expect($candidatura->fresh()->retirada_em)->not->toBeNull();
    $this->assertDatabaseHas('audit_logs', [
        'action' => 'candidatura.retirada', 'target_id' => $candidatura->id,
    ]);
});

test('retirar candidatura aprovada → 409 estado_invalido (CA-8)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id);
    $candidatura = Candidatura::factory()->create([
        'vaga_id' => $vaga->id, 'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Aprovada,
    ]);

    $this->actingAs($prof)->deleteJson("/api/candidaturas/{$candidatura->id}")
        ->assertStatus(409)
        ->assertJsonPath('erro', 'estado_invalido')
        ->assertJsonPath('mensagem', 'Esta candidatura não pode mais ser retirada.');

    expect($candidatura->fresh()->estado)->toBe(CandidaturaEstado::Aprovada);
});

test('não-dono não retira candidatura alheia → 404 (CA-8)', function () {
    $funcao = Funcao::factory()->create();
    $dono = profCand(['funcao_id' => $funcao->id]);
    $outro = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id);
    $candidatura = Candidatura::factory()->create([
        'vaga_id' => $vaga->id, 'profissional_id' => $dono->id,
        'estado' => CandidaturaEstado::Pendente,
    ]);

    $this->actingAs($outro)->deleteJson("/api/candidaturas/{$candidatura->id}")->assertStatus(404);
    expect($candidatura->fresh()->estado)->toBe(CandidaturaEstado::Pendente);
});

test('contratante não retira candidatura → 403 (CA-8 / RBAC)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id);
    $candidatura = Candidatura::factory()->create([
        'vaga_id' => $vaga->id, 'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Pendente,
    ]);
    $contratante = User::factory()->contratante()->ativo()->create();

    $this->actingAs($contratante)->deleteJson("/api/candidaturas/{$candidatura->id}")->assertStatus(403);
});

// ───────────────────────── STORY-051 — snapshot do breakdown persistido ─────────────────────────

test('candidatura persiste o score_breakdown (snapshot completo) e alerta_habitualidade false (STORY-051 CA-4)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id]);
    $vaga = vagaCand($funcao->id);

    $this->actingAs($prof)->postJson("/api/vagas/{$vaga->id}/candidaturas")->assertStatus(201);

    $candidatura = Candidatura::query()->where('vaga_id', $vaga->id)->where('profissional_id', $prof->id)->firstOrFail();
    expect($candidatura->score_breakdown)->toBeArray()
        ->and($candidatura->score_breakdown['total'])->toBe($candidatura->score_no_momento)
        ->and($candidatura->score_breakdown['breakdown'])->toHaveKeys(['funcao', 'distancia', 'historico', 'nivel'])
        ->and($candidatura->score_breakdown['breakdown']['funcao'])->toHaveKeys(['pontos', 'pontos_max', 'estado', 'descricao'])
        ->and($candidatura->alerta_habitualidade)->toBeFalse();
});

test('candidatura de MEI na 3ª alocação persiste alerta_habitualidade true sem bloquear (STORY-051 CA-5)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profCand(['funcao_id' => $funcao->id, 'tipo_pessoa' => 'MEI']);
    $contratante = contratanteCand();

    // Duas alocações vivas na mesma semana/estabelecimento, em horários que NÃO conflitam com a
    // vaga-alvo (senão o gate de conflito barraria antes da habitualidade) → a 3ª dispara o
    // alerta (MEI não bloqueia).
    foreach ([[2, 5], [6, 9]] as [$ini, $fim]) {
        $outra = vagaCand($funcao->id, [
            'contratante_id' => $contratante->id,
            'data_inicio' => now()->addDays(3)->setTime($ini, 0),
            'data_fim' => now()->addDays(3)->setTime($fim, 0),
        ]);
        Candidatura::factory()->create([
            'vaga_id' => $outra->id, 'profissional_id' => $prof->id,
            'estado' => CandidaturaEstado::Pendente,
        ]);
    }
    $alvo = vagaCand($funcao->id, ['contratante_id' => $contratante->id]);

    $this->actingAs($prof)->postJson("/api/vagas/{$alvo->id}/candidaturas")
        ->assertStatus(201)
        ->assertJsonPath('alerta', true);

    $candidatura = Candidatura::query()->where('vaga_id', $alvo->id)->where('profissional_id', $prof->id)->firstOrFail();
    expect($candidatura->alerta_habitualidade)->toBeTrue();
});
