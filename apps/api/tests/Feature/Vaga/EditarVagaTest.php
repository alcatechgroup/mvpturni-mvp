<?php

// STORY-052 — PATCH /api/vagas/{vaga}: edição material da vaga (PDR-009).
// CA-1 (RBAC dono), CA-2 (detecção material), CA-3 (snapshot + transição + audit + evento),
// CA-4 (material sem candidatos), CA-5 (não material in-place), CA-6 (snapshot imutável),
// 409 (vaga não editável). GET /editar (CA-10 — carga do form).

use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Events\VagaEditadaMaterialmente;
use App\Models\AuditLog;
use App\Models\Candidatura;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;

uses(RefreshDatabase::class);

function donoComVaga(array $vagaOver = []): array
{
    $func = Funcao::firstOrCreate(['slug' => 'garcom'], ['nome' => 'Garçom', 'ativo' => true]);
    $dono = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::create([
        'user_id' => $dono->id, 'nome_estabelecimento' => 'Bar do Zé',
        'tipo_operacao' => 'bar', 'cidade' => 'São Paulo', 'uf' => 'SP',
    ]);
    $vaga = Vaga::factory()->create(array_merge([
        'contratante_id' => $dono->id,
        'funcao_id' => $func->id,
        'data_inicio' => now()->addDays(5)->setTime(18, 0),
        'data_fim' => now()->addDays(5)->setTime(23, 0),
        'valor' => 120.00,
        'posicoes' => 2,
        'observacoes' => 'Avental preto.',
        'versao_atual' => 1,
    ], $vagaOver));

    return [$dono, $vaga, $func];
}

/** Payload espelhando a vaga; `$over` aplica a edição. */
function payloadEditar(Vaga $vaga, array $over = []): array
{
    return array_merge([
        'funcao_id' => $vaga->funcao_id,
        'data_inicio' => $vaga->data_inicio->toIso8601String(),
        'data_fim' => $vaga->data_fim->toIso8601String(),
        'valor' => (float) $vaga->valor,
        'posicoes' => $vaga->posicoes,
        'observacoes' => $vaga->observacoes,
    ], $over);
}

// ───────────────────────── CA-1 — RBAC ─────────────────────────

test('profissional recebe 403 ao tentar editar vaga (CA-1)', function () {
    [, $vaga] = donoComVaga();
    $prof = User::factory()->profissional()->ativo()->create();

    $this->actingAs($prof)->patchJson("/api/vagas/{$vaga->id}", payloadEditar($vaga, ['valor' => 200]))
        ->assertStatus(403);
});

test('contratante não-dono recebe 403 (CA-1)', function () {
    [, $vaga] = donoComVaga();
    $outro = User::factory()->contratante()->ativo()->create();

    $this->actingAs($outro)->patchJson("/api/vagas/{$vaga->id}", payloadEditar($vaga, ['valor' => 200]))
        ->assertStatus(403);
});

test('não autenticado recebe 401', function () {
    [, $vaga] = donoComVaga();

    $this->patchJson("/api/vagas/{$vaga->id}", payloadEditar($vaga, ['valor' => 200]))->assertStatus(401);
});

// ───────────────────────── CA-5 — edição NÃO material ─────────────────────────

test('payload idêntico → 200 material=false, sem snapshot, sem evento (CA-5)', function () {
    Event::fake([VagaEditadaMaterialmente::class]);
    [$dono, $vaga] = donoComVaga();

    $res = $this->actingAs($dono)->patchJson("/api/vagas/{$vaga->id}", payloadEditar($vaga));

    $res->assertOk()->assertJsonPath('material', false)->assertJsonPath('diff', []);
    expect(VagaVersao::where('vaga_id', $vaga->id)->count())->toBe(0);
    expect($vaga->fresh()->versao_atual)->toBe(1);
    Event::assertNotDispatched(VagaEditadaMaterialmente::class);
});

// ───────────────────────── CA-3 — material com candidatos pendentes ─────────────────────────

test('edição material com candidatos pendentes: snapshot + transição + audit + evento (CA-3)', function () {
    Event::fake([VagaEditadaMaterialmente::class]);
    [$dono, $vaga] = donoComVaga();
    $c1 = Candidatura::factory()->create(['vaga_id' => $vaga->id, 'estado' => CandidaturaEstado::Pendente]);
    $c2 = Candidatura::factory()->create(['vaga_id' => $vaga->id, 'estado' => CandidaturaEstado::Pendente]);

    $res = $this->actingAs($dono)->patchJson("/api/vagas/{$vaga->id}", payloadEditar($vaga, ['valor' => 150.00]));

    $res->assertOk()
        ->assertJsonPath('material', true)
        ->assertJsonPath('candidatos_notificados', 2)
        ->assertJsonPath('diff.0.campo', 'valor')
        ->assertJsonPath('diff.0.antes', 120)
        ->assertJsonPath('diff.0.depois', 150);

    // snapshot v2 + versao bumpada
    $vaga->refresh();
    expect($vaga->versao_atual)->toBe(2);
    $v2 = VagaVersao::where('vaga_id', $vaga->id)->where('versao', 2)->first();
    expect($v2)->not->toBeNull()->and((float) $v2->snapshot['valor'])->toBe(150.0);

    // candidaturas pendentes → revisão, com prazo
    foreach ([$c1, $c2] as $c) {
        $c->refresh();
        expect($c->estado)->toBe(CandidaturaEstado::PendenteRevisaoAposEdicao);
        expect($c->revisao_prazo_em)->not->toBeNull();
    }

    // audit + evento
    expect(AuditLog::where('action', 'vaga.editada_materialmente')->where('target_id', $vaga->id)->count())->toBe(1);
    Event::assertDispatched(VagaEditadaMaterialmente::class, function ($e) use ($vaga, $c1, $c2) {
        return $e->vaga->id === $vaga->id
            && count($e->candidatosNotificadosIds) === 2
            && in_array($c1->id, $e->candidatosNotificadosIds, true)
            && in_array($c2->id, $e->candidatosNotificadosIds, true);
    });
});

test('candidatura já em revisão não é tocada de novo, mas conta como pendente (CA-3)', function () {
    Event::fake([VagaEditadaMaterialmente::class]);
    [$dono, $vaga] = donoComVaga();
    $jaRevisao = Candidatura::factory()->create([
        'vaga_id' => $vaga->id,
        'estado' => CandidaturaEstado::PendenteRevisaoAposEdicao,
        'revisao_prazo_em' => now()->addHours(10),
    ]);
    $prazoAntigo = $jaRevisao->revisao_prazo_em->toIso8601String();

    $res = $this->actingAs($dono)->patchJson("/api/vagas/{$vaga->id}", payloadEditar($vaga, ['posicoes' => 3]));

    // ninguém recém-movido → 0 notificados → sem evento
    $res->assertOk()->assertJsonPath('candidatos_notificados', 0);
    Event::assertNotDispatched(VagaEditadaMaterialmente::class);
    // prazo da que já estava em revisão não muda
    expect($jaRevisao->fresh()->revisao_prazo_em->toIso8601String())->toBe($prazoAntigo);
    // mas o audit registra que há 1 candidato pendente
    $log = AuditLog::where('action', 'vaga.editada_materialmente')->where('target_id', $vaga->id)->first();
    expect($log->payload['candidatos_pendentes'])->toBe(1);
});

// ───────────────────────── CA-4 — material sem candidatos ─────────────────────────

test('edição material sem candidatos: snapshot + update, sem evento (CA-4)', function () {
    Event::fake([VagaEditadaMaterialmente::class]);
    [$dono, $vaga] = donoComVaga();

    $res = $this->actingAs($dono)->patchJson("/api/vagas/{$vaga->id}", payloadEditar($vaga, ['valor' => 180.00]));

    $res->assertOk()->assertJsonPath('material', true)->assertJsonPath('candidatos_notificados', 0);
    expect(VagaVersao::where('vaga_id', $vaga->id)->where('versao', 2)->exists())->toBeTrue();
    expect((float) $vaga->fresh()->valor)->toBe(180.00);
    Event::assertNotDispatched(VagaEditadaMaterialmente::class);
});

// ───────────────────────── prazo (PDR-009) ─────────────────────────

test('prazo de revisão = início do turno quando ele cai antes de 24h', function () {
    [$dono, $vaga] = donoComVaga([
        'data_inicio' => now()->addHours(6), 'data_fim' => now()->addHours(12),
    ]);
    $c = Candidatura::factory()->create(['vaga_id' => $vaga->id, 'estado' => CandidaturaEstado::Pendente]);

    $this->actingAs($dono)->patchJson("/api/vagas/{$vaga->id}", payloadEditar($vaga, ['valor' => 150.00]))->assertOk();

    // início (≈ +6h) < agora+24h → prazo = início do turno
    expect($c->fresh()->revisao_prazo_em->lessThan(now()->addHours(7)))->toBeTrue();
});

// ───────────────────────── 409 — vaga não editável ─────────────────────────

test('editar vaga fechada → 409 (fora de escopo da estória)', function () {
    [$dono, $vaga] = donoComVaga();
    $vaga->update(['estado' => VagaEstado::Fechada, 'fechada_em' => now()]);

    $this->actingAs($dono)->patchJson("/api/vagas/{$vaga->id}", payloadEditar($vaga, ['valor' => 150.00]))
        ->assertStatus(409);
});

// ───────────────────────── validação ─────────────────────────

test('data_fim ≤ data_inicio → 422 (espelho do publicar)', function () {
    [$dono, $vaga] = donoComVaga();

    $this->actingAs($dono)->patchJson("/api/vagas/{$vaga->id}", payloadEditar($vaga, [
        'data_fim' => $vaga->data_inicio->copy()->subHour()->toIso8601String(),
    ]))->assertStatus(422)->assertJsonValidationErrors('data_fim');
});

// ───────────────────────── CA-10 — GET /editar ─────────────────────────

test('GET /editar devolve valores atuais + contagem de candidatos a notificar (CA-10)', function () {
    [$dono, $vaga] = donoComVaga();
    Candidatura::factory()->create(['vaga_id' => $vaga->id, 'estado' => CandidaturaEstado::Pendente]);
    Candidatura::factory()->create(['vaga_id' => $vaga->id, 'estado' => CandidaturaEstado::PendenteRevisaoAposEdicao]);
    Candidatura::factory()->create(['vaga_id' => $vaga->id, 'estado' => CandidaturaEstado::Retirada]);

    $this->actingAs($dono)->getJson("/api/vagas/{$vaga->id}/editar")
        ->assertOk()
        ->assertJsonPath('editavel', true)
        ->assertJsonPath('valor', 120)
        ->assertJsonPath('posicoes', 2)
        ->assertJsonPath('candidatos_em_revisao', 2); // pendente + em-revisão; retirada não conta
});

test('GET /editar de não-dono → 403', function () {
    [, $vaga] = donoComVaga();
    $outro = User::factory()->contratante()->ativo()->create();

    $this->actingAs($outro)->getJson("/api/vagas/{$vaga->id}/editar")->assertStatus(403);
});
