<?php

// STORY-058 — POST /api/candidaturas/{candidatura}/aprovar (RBAC contratante dono — CA-1,
// corrigido pelo PO em 2026-06-04: aprovação é do contratante no WebApp, não do admin).
// Cobre CA-1 (endpoint + RBAC), CA-2 (transação: Turno confirmado + AceiteEletronicoTurno +
// job de pré-autorização), CA-3 (PF 3ª → 422 PDR-002), CA-4 (PJ 3ª → requer override; com
// override carimba cláusula), CA-5 (idempotência de clique duplo), CA-7 (audit log) e as
// bordas de vaga fechada/candidatura inválida/rollback.

use App\Enums\CandidaturaEstado;
use App\Enums\TurnoStatus;
use App\Enums\VagaEstado;
use App\Jobs\PreAutorizarTurnoJob;
use App\Models\AceiteEletronicoTurno;
use App\Models\AuditLog;
use App\Models\Candidatura;
use App\Models\ContratanteProfile;
use App\Models\ProfissionalProfile;
use App\Models\TemplateVersao;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use Carbon\CarbonImmutable;
use Database\Seeders\TemplatesContratuaisSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;

uses(RefreshDatabase::class);

beforeEach(function () {
    User::factory()->admin()->create();
    test()->seed(TemplatesContratuaisSeeder::class);
});

/** Contratante ativo com perfil de estabelecimento. */
function contratanteAprov(): User
{
    $contratante = User::factory()->contratante()->ativo()->create();
    $cnpj = (string) fake()->unique()->numerify('##############');
    ContratanteProfile::create([
        'user_id' => $contratante->id,
        'cnpj_encrypted' => $cnpj,
        'cnpj_hash' => hash_hmac('sha256', $cnpj, (string) config('app.key')),
        'nome_estabelecimento' => 'Bar do Zé Ltda',
        'apelido_estabelecimento' => 'Bar do Zé',
        'cidade' => 'São Paulo',
        'endereco_completo' => 'Rua das Flores, 100 — Centro, São Paulo/SP',
    ]);

    return $contratante;
}

function profAprov(string $tipo = 'MEI'): User
{
    $user = User::factory()->profissional()->ativo()->create(['name' => 'Júlia Santos']);
    ProfissionalProfile::factory()->create(['user_id' => $user->id, 'tipo_pessoa' => $tipo]);

    return $user;
}

/** Vaga aberta futura (R$ 200,00) + candidatura pendente do profissional. */
function cenarioAprov(User $contratante, User $prof, array $vagaOver = []): Candidatura
{
    // MONDAY explícito: o locale pt-BR muda o default de startOfWeek() p/ domingo (PDR-002 = seg→dom).
    $inicio = CarbonImmutable::now()->addWeeks(2)
        ->startOfWeek(\Carbon\CarbonInterface::MONDAY)->addDays(2)->setTime(18, 0);
    $vaga = Vaga::factory()->create(array_merge([
        'contratante_id' => $contratante->id,
        'valor' => 200.00,
        'data_inicio' => $inicio,
        'data_fim' => $inicio->addHours(6),
        'posicoes' => 1,
    ], $vagaOver));

    return Candidatura::factory()->create([
        'vaga_id' => $vaga->id,
        'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Pendente,
    ]);
}

/** Turno pré-existente do par na mesma semana da vaga-alvo (para a 3ª alocação). */
function turnoExistente(User $prof, User $contratante, CarbonImmutable $inicio): Turno
{
    return Turno::factory()->create([
        'profissional_id' => $prof->id,
        'contratante_id' => $contratante->id,
        'estabelecimento_id' => $contratante->id,
        'data_inicio' => $inicio,
        'data_fim' => $inicio->addHours(6),
    ]);
}

// ─── CA-1 — endpoint + RBAC ───────────────────────────────────────────────────

test('CA-1: contratante dono aprova candidatura pendente → 201 com o turno', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov());

    $resp = test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar");

    $resp->assertCreated()->assertJsonPath('turno.status', 'confirmado');
    expect($resp->json('turno.id'))->not->toBeNull();
});

test('CA-1: contratante NÃO-dono → 403 e nada criado', function () {
    $candidatura = cenarioAprov(contratanteAprov(), profAprov());
    $intruso = contratanteAprov();

    test()->actingAs($intruso)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertForbidden();

    expect(Turno::count())->toBe(0);
});

test('CA-1: profissional autenticado → 403', function () {
    $prof = profAprov();
    $candidatura = cenarioAprov(contratanteAprov(), $prof);

    test()->actingAs($prof)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertForbidden();
});

test('CA-1: sem sessão → 401; candidatura inexistente → 404', function () {
    test()->postJson('/api/candidaturas/0197a000-0000-7000-8000-000000000000/aprovar')
        ->assertUnauthorized();

    test()->actingAs(contratanteAprov())
        ->postJson('/api/candidaturas/0197a000-0000-7000-8000-000000000000/aprovar')
        ->assertNotFound();
});

// ─── CA-2 — transação: Turno + Aceite + job ──────────────────────────────────

test('CA-2: aprovação cria Turno confirmado com financeiro congelado (15% PDR-004)', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov());

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertCreated()
        ->assertJsonPath('turno.valor', '200.00')
        ->assertJsonPath('turno.taxa_turni', '30.00')
        ->assertJsonPath('turno.total_contratante', '230.00');

    $turno = Turno::firstOrFail();
    $vaga = $candidatura->vaga;
    expect($turno->status)->toBe(TurnoStatus::Confirmado)
        ->and($turno->candidatura_id)->toBe($candidatura->id)
        ->and($turno->vaga_id)->toBe($vaga->id)
        ->and($turno->profissional_id)->toBe($candidatura->profissional_id)
        ->and($turno->contratante_id)->toBe($contratante->id)
        ->and($turno->estabelecimento_id)->toBe($contratante->id) // MVP: estabelecimento = contratante
        ->and($turno->data_inicio->equalTo($vaga->data_inicio))->toBeTrue()
        ->and($turno->data_fim->equalTo($vaga->data_fim))->toBeTrue();
});

test('CA-2: candidatura transita para aprovada e a vaga preenche a posição (fecha na última)', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov()); // 1 posição

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertCreated();

    $candidatura->refresh();
    expect($candidatura->estado)->toBe(CandidaturaEstado::Aprovada)
        ->and($candidatura->aprovada_em)->not->toBeNull();

    $vaga = $candidatura->vaga->refresh();
    expect($vaga->posicoes_preenchidas)->toBe(1)
        ->and($vaga->estado)->toBe(VagaEstado::Fechada); // domain/vaga.md: última posição fecha
});

test('CA-2: vaga com múltiplas posições continua aberta após a 1ª aprovação', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov(), ['posicoes' => 2]);

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertCreated();

    $vaga = $candidatura->vaga->refresh();
    expect($vaga->posicoes_preenchidas)->toBe(1)->and($vaga->estado)->toBe(VagaEstado::Aberta);
});

test('CA-2: aceite eletrônico emitido referencia a versão ativa do template do tipo de pessoa', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov('MEI'));

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertCreated();

    $aceite = AceiteEletronicoTurno::firstOrFail();
    $versaoMei = \App\Models\Template::where('slug', 'mei_pj_b2b')->first()->versaoAtiva;

    expect($aceite->template_versao_id)->toBe($versaoMei->id)
        ->and($aceite->habitualidade_override)->toBeFalse()
        ->and($aceite->ip)->not->toBeNull()
        ->and($aceite->fingerprint)->not->toBeNull()
        ->and($aceite->conteudo_renderizado)
            ->toContain('Júlia Santos')
            ->toContain('Bar do Zé Ltda')
            ->toContain('R$ 200,00')   // valor do turno
            ->toContain('R$ 30,00')    // taxa Turni
            ->toContain('R$ 230,00')   // total contratante
        ->and($aceite->dados_renderizados)->toHaveKeys([
            'profissional.nome', 'contratante.razao_social', 'turno.valor',
            'turno.taxa_turni', 'turno.total_contratante', 'aceite.timestamp',
        ]);
});

test('CA-2: profissional PF usa o template pf_autonomo_eventual', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov('PF'));

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertCreated();

    $versaoPf = \App\Models\Template::where('slug', 'pf_autonomo_eventual')->first()->versaoAtiva;
    expect(AceiteEletronicoTurno::firstOrFail()->template_versao_id)->toBe($versaoPf->id);
});

test('CA-2/CA-6: aprovação despacha o job de pré-autorização (assíncrono — ADR-002)', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov());

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertCreated();

    $turnoId = Turno::firstOrFail()->id;
    Queue::assertPushed(PreAutorizarTurnoJob::class, fn ($job) => $job->turnoId === $turnoId);
});

test('CA-2 (rollback): template sem versão ativa → erro e NADA persiste', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov());
    TemplateVersao::query()->update(['ativa' => false]); // estado inválido simulado

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertServerError();

    expect(Turno::count())->toBe(0)
        ->and(AceiteEletronicoTurno::count())->toBe(0)
        ->and($candidatura->refresh()->estado)->toBe(CandidaturaEstado::Pendente)
        ->and($candidatura->vaga->refresh()->posicoes_preenchidas)->toBe(0);
    Queue::assertNothingPushed();
});

// ─── CA-3 — habitualidade PF 3ª bloqueia ─────────────────────────────────────

test('CA-3: PF na 3ª alocação da semana → 422 com a mensagem PDR-002 e sem turno', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $prof = profAprov('PF');
    $candidatura = cenarioAprov($contratante, $prof);
    $inicio = CarbonImmutable::parse($candidatura->vaga->data_inicio);
    turnoExistente($prof, $contratante, $inicio->subDays(2));
    turnoExistente($prof, $contratante, $inicio->subDay());

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertUnprocessable()
        ->assertJsonPath('erro', 'habitualidade_bloqueio')
        ->assertJsonPath('mensagem', 'este profissional é PF e já tem 2 alocações nesta semana neste estabelecimento; bloqueado por PDR-002');

    expect(Turno::count())->toBe(2) // só os pré-existentes
        ->and($candidatura->refresh()->estado)->toBe(CandidaturaEstado::Pendente);
    Queue::assertNothingPushed();
});

test('CA-3/CA-9: PF com 2 turnos na semana ANTERIOR aprova normal (virada reseta)', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $prof = profAprov('PF');
    $candidatura = cenarioAprov($contratante, $prof);
    $semanaAnterior = CarbonImmutable::parse($candidatura->vaga->data_inicio)->subWeek();
    turnoExistente($prof, $contratante, $semanaAnterior);
    turnoExistente($prof, $contratante, $semanaAnterior->addDay());

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertCreated();
});

// ─── CA-4 — habitualidade PJ 3ª: override explícito ──────────────────────────

test('CA-4: PJ na 3ª sem override → 422 requer_override e sem turno', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $prof = profAprov('MEI');
    $candidatura = cenarioAprov($contratante, $prof);
    $inicio = CarbonImmutable::parse($candidatura->vaga->data_inicio);
    turnoExistente($prof, $contratante, $inicio->subDays(2));
    turnoExistente($prof, $contratante, $inicio->subDay());

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertUnprocessable()
        ->assertJsonPath('erro', 'requer_override');

    expect(Turno::count())->toBe(2);
    Queue::assertNothingPushed();
});

test('CA-4: PJ na 3ª com override=true → turno criado + cláusula de risco no aceite', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $prof = profAprov('MEI');
    $candidatura = cenarioAprov($contratante, $prof);
    $inicio = CarbonImmutable::parse($candidatura->vaga->data_inicio);
    turnoExistente($prof, $contratante, $inicio->subDays(2));
    turnoExistente($prof, $contratante, $inicio->subDay());

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar", ['override' => true])
        ->assertCreated();

    $aceite = AceiteEletronicoTurno::firstOrFail();
    expect($aceite->habitualidade_override)->toBeTrue()
        ->and($aceite->conteudo_renderizado)
            ->toContain('Aceite consciente de risco de habitualidade')
            ->toContain('assume esse risco de forma integral e exclusiva');
});

test('CA-4 (borda): override=true SEM 3ª alocação não carimba cláusula (override só vale onde há risco)', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov('MEI'));

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar", ['override' => true])
        ->assertCreated();

    $aceite = AceiteEletronicoTurno::firstOrFail();
    expect($aceite->habitualidade_override)->toBeFalse()
        ->and($aceite->conteudo_renderizado)->not->toContain('Aceite consciente de risco');
});

test('CA-4: PF na 3ª NÃO aceita override (bloqueio é duro)', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $prof = profAprov('PF');
    $candidatura = cenarioAprov($contratante, $prof);
    $inicio = CarbonImmutable::parse($candidatura->vaga->data_inicio);
    turnoExistente($prof, $contratante, $inicio->subDays(2));
    turnoExistente($prof, $contratante, $inicio->subDay());

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar", ['override' => true])
        ->assertUnprocessable()
        ->assertJsonPath('erro', 'habitualidade_bloqueio');
});

// ─── CA-5 — idempotência (clique duplo / double-submit) ──────────────────────

test('CA-5: aprovar duas vezes → um único turno/aceite; 2ª responde 409 ja_aprovada', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov());

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertCreated();
    $turnoId = Turno::firstOrFail()->id;

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertConflict()
        ->assertJsonPath('erro', 'ja_aprovada')
        ->assertJsonPath('turno_id', $turnoId);

    expect(Turno::count())->toBe(1)
        ->and(AceiteEletronicoTurno::count())->toBe(1)
        ->and(Queue::pushed(PreAutorizarTurnoJob::class))->toHaveCount(1);
});

// ─── Bordas de estado — vaga/candidatura ─────────────────────────────────────

test('vaga fechada → 422 vaga_fechada', function () {
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov());
    $candidatura->vaga->update(['estado' => VagaEstado::Fechada, 'posicoes_preenchidas' => 1]);

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertUnprocessable()
        ->assertJsonPath('erro', 'vaga_fechada');
});

test('candidatura retirada → 422 candidatura_invalida', function () {
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov());
    $candidatura->update(['estado' => CandidaturaEstado::Retirada, 'retirada_em' => now()]);

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertUnprocessable()
        ->assertJsonPath('erro', 'candidatura_invalida');
});

// ─── CA-7 — audit log imutável ───────────────────────────────────────────────

test('CA-7: aprovação grava turno.criado e aceite_eletronico.emitido no audit log', function () {
    Queue::fake();
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov());

    test()->actingAs($contratante)
        ->postJson("/api/candidaturas/{$candidatura->id}/aprovar")
        ->assertCreated();

    $turno = Turno::firstOrFail();
    $criado = AuditLog::where('action', 'turno.criado')->first();
    $emitido = AuditLog::where('action', 'aceite_eletronico.emitido')->first();

    expect($criado)->not->toBeNull()
        ->and($criado->actor_id)->toBe($contratante->id)
        ->and($criado->target_id)->toBe($turno->id)
        ->and($criado->payload['candidatura_id'] ?? null)->toBe($candidatura->id)
        ->and($emitido)->not->toBeNull()
        ->and($emitido->target_type)->toBe('AceiteEletronicoTurno');
});

// ─── Contrato do painel (SCREEN-058 D1) — preview financeiro ─────────────────

test('GET /api/vagas/{vaga}/candidatos passa a incluir o preview financeiro da vaga', function () {
    $contratante = contratanteAprov();
    $candidatura = cenarioAprov($contratante, profAprov());

    test()->actingAs($contratante)
        ->getJson("/api/vagas/{$candidatura->vaga_id}/candidatos")
        ->assertOk()
        ->assertJsonPath('vaga.valor', '200.00')
        ->assertJsonPath('vaga.taxa_turni', '30.00')
        ->assertJsonPath('vaga.total_contratante', '230.00');
});
