<?php

// STORY-049 — GET /api/vagas/{vaga}/detalhe: detalhe + breakdown explicável.
// Cobre CA-1 (shape unificado + score_breakdown STORY-045), CA-3 (estados ok/partial/miss
// por componente), CA-5 (pode_candidatar + motivo_bloqueio via gate), CA-6 (ja_candidatou +
// candidatura), CA-7 (RBAC profissional/contratante) e os 404 de visibilidade (§4.7).

use App\Domain\Avaliacao\AvaliacoesPendentesProfissional;
use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Models\Candidatura;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/** Profissional ativo com perfil (geo SP + raio amplo por padrão). */
function profDet(array $perfil = []): User
{
    $user = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->create(array_merge(['user_id' => $user->id], $perfil));

    return $user;
}

/** Cria um contratante com estabelecimento (sem factory — o modelo não tem uma). */
function contratanteComEstabelecimento(array $perfil = []): User
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

/** Vaga aberta futura na Grande SP, com contratante + estabelecimento. */
function vagaDet(int $funcaoId, array $over = []): Vaga
{
    $contratanteId = $over['contratante_id'] ?? contratanteComEstabelecimento()->id;
    unset($over['contratante_id']);

    return Vaga::factory()->create(array_merge([
        'contratante_id' => $contratanteId,
        'funcao_id' => $funcaoId,
        'estado' => VagaEstado::Aberta,
        'data_inicio' => now()->addDays(3),
        'data_fim' => now()->addDays(3)->addHours(6),
        'valor' => 150.00,
        'cidade' => 'São Paulo',
        'lat' => -23.55, 'lng' => -46.63,
    ], $over));
}

// ───────────────────────── CA-1 — shape unificado + RBAC ─────────────────────────

test('detalhe devolve o contrato unificado com score_breakdown (CA-1)', function () {
    $funcao = Funcao::factory()->create(['nome' => 'Garçom']);
    $prof = profDet(['funcao_id' => $funcao->id]);
    $vaga = vagaDet($funcao->id);

    $res = $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe");

    $res->assertStatus(200)
        ->assertJsonStructure([
            'id', 'funcao', 'estabelecimento', 'cidade', 'data_inicio', 'data_fim',
            'valor', 'distancia_km',
            'score_breakdown' => [
                'total',
                'componentes' => ['funcao', 'distancia', 'historico', 'nivel'],
                'breakdown' => [
                    'funcao' => ['pontos', 'pontos_max', 'estado', 'descricao'],
                    'distancia' => ['pontos', 'pontos_max', 'estado', 'descricao'],
                    'historico' => ['pontos', 'pontos_max', 'estado', 'descricao'],
                    'nivel' => ['pontos', 'pontos_max', 'estado', 'descricao'],
                ],
            ],
            'pode_candidatar', 'ja_candidatou', 'candidatura', 'motivo_bloqueio',
        ])
        ->assertJsonPath('funcao', 'Garçom')
        ->assertJsonPath('estabelecimento', 'Bar do Zé')
        ->assertJsonPath('cidade', 'São Paulo')
        ->assertJsonPath('valor', 150)
        ->assertJsonPath('ja_candidatou', false)
        ->assertJsonPath('candidatura', null)
        ->assertJsonPath('pode_candidatar', true)
        ->assertJsonPath('motivo_bloqueio', null);
});

test('estabelecimento cai no nome quando não há apelido', function () {
    $funcao = Funcao::factory()->create();
    $prof = profDet(['funcao_id' => $funcao->id]);
    $contratante = contratanteComEstabelecimento([
        'nome_estabelecimento' => 'Hotel Aurora S/A',
        'apelido_estabelecimento' => null,
    ]);
    $vaga = vagaDet($funcao->id, ['contratante_id' => $contratante->id]);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")
        ->assertStatus(200)
        ->assertJsonPath('estabelecimento', 'Hotel Aurora S/A');
});

test('contratante recebe 403 no detalhe (RBAC — CA-7)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profDet(['funcao_id' => $funcao->id]);
    $vaga = vagaDet($funcao->id);
    $contratante = User::factory()->contratante()->ativo()->create();

    $this->actingAs($contratante)->getJson("/api/vagas/{$vaga->id}/detalhe")->assertStatus(403);
});

test('não autenticado recebe 401', function () {
    $funcao = Funcao::factory()->create();
    profDet(['funcao_id' => $funcao->id]);
    $vaga = vagaDet($funcao->id);

    $this->getJson("/api/vagas/{$vaga->id}/detalhe")->assertStatus(401);
});

// ───────────────────────── 404 de visibilidade (§4.7) ─────────────────────────

test('vaga inexistente → 404', function () {
    $prof = profDet();

    $this->actingAs($prof)->getJson('/api/vagas/999999/detalhe')->assertStatus(404);
});

test('vaga fechada → 404 (não está mais disponível)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profDet(['funcao_id' => $funcao->id]);
    $vaga = vagaDet($funcao->id, ['estado' => VagaEstado::Fechada]);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")->assertStatus(404);
});

test('vaga cancelada → 404', function () {
    $funcao = Funcao::factory()->create();
    $prof = profDet(['funcao_id' => $funcao->id]);
    $vaga = vagaDet($funcao->id, ['estado' => VagaEstado::Cancelada]);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")->assertStatus(404);
});

test('vaga no passado → 404', function () {
    $funcao = Funcao::factory()->create();
    $prof = profDet(['funcao_id' => $funcao->id]);
    $vaga = vagaDet($funcao->id, [
        'data_inicio' => now()->subDays(1),
        'data_fim' => now()->subDays(1)->addHours(4),
    ]);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")->assertStatus(404);
});

test('profissional sem perfil → 404', function () {
    $funcao = Funcao::factory()->create();
    $user = User::factory()->profissional()->ativo()->create();
    $vaga = vagaDet($funcao->id);

    $this->actingAs($user)->getJson("/api/vagas/{$vaga->id}/detalhe")->assertStatus(404);
});

// ───────────────────────── CA-3 — estados do breakdown por componente ─────────────────────────

test('função primária bate → estado ok 40/40 (CA-3)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profDet(['funcao_id' => $funcao->id]);
    $vaga = vagaDet($funcao->id);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")
        ->assertJsonPath('score_breakdown.breakdown.funcao.pontos', 40)
        ->assertJsonPath('score_breakdown.breakdown.funcao.pontos_max', 40)
        ->assertJsonPath('score_breakdown.breakdown.funcao.estado', 'ok')
        ->assertJsonPath('score_breakdown.breakdown.funcao.descricao', 'Sua função primária bate');
});

test('função secundária bate → estado partial 25/40 (CA-3)', function () {
    $primaria = Funcao::factory()->create();
    $secundaria = Funcao::factory()->create();
    $prof = profDet([
        'funcao_id' => $primaria->id,
        'funcoes_secundarias' => [$secundaria->id],
    ]);
    $vaga = vagaDet($secundaria->id);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")
        ->assertJsonPath('score_breakdown.breakdown.funcao.pontos', 25)
        ->assertJsonPath('score_breakdown.breakdown.funcao.estado', 'partial');
});

test('função não corresponde → estado miss 0/40 (CA-3)', function () {
    $minha = Funcao::factory()->create();
    $outra = Funcao::factory()->create();
    $prof = profDet(['funcao_id' => $minha->id]);
    $vaga = vagaDet($outra->id);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")
        ->assertJsonPath('score_breakdown.breakdown.funcao.pontos', 0)
        ->assertJsonPath('score_breakdown.breakdown.funcao.estado', 'miss');
});

test('distância sem geo do profissional → miss + distancia_km null (§4.8)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profDet(['funcao_id' => $funcao->id, 'lat' => null, 'lng' => null]);
    $vaga = vagaDet($funcao->id);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")
        ->assertJsonPath('distancia_km', null)
        ->assertJsonPath('score_breakdown.breakdown.distancia.pontos', 0)
        ->assertJsonPath('score_breakdown.breakdown.distancia.estado', 'miss');
});

test('histórico parcial (4.8★) → estado partial (CA-3)', function () {
    $funcao = Funcao::factory()->create();
    // Default do factory: score 4.8 / 80 turnos → 24/30 (partial).
    $prof = profDet(['funcao_id' => $funcao->id]);
    $vaga = vagaDet($funcao->id);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")
        ->assertJsonPath('score_breakdown.breakdown.historico.estado', 'partial')
        ->assertJsonPath('score_breakdown.breakdown.historico.pontos_max', 30);
});

test('sem histórico (Iniciante 0 turnos) → miss + total baixo (CA-3 / cold start)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profDet([
        'funcao_id' => $funcao->id,
        'nivel' => 'Iniciante', 'score' => 0, 'turnos_realizados' => 0,
    ]);
    $vaga = vagaDet($funcao->id);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")
        ->assertJsonPath('score_breakdown.breakdown.historico.estado', 'miss')
        ->assertJsonPath('score_breakdown.breakdown.historico.pontos', 0)
        ->assertJsonPath('score_breakdown.breakdown.nivel.estado', 'miss')
        // Função ok (40) + distância ok (20) = 60.
        ->assertJsonPath('score_breakdown.total', 60);
});

// ───────────────────────── CA-5 — gate / motivo_bloqueio ─────────────────────────

test('gate ativo → pode_candidatar false + motivo_bloqueio (CA-5)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profDet(['funcao_id' => $funcao->id]);
    $vaga = vagaDet($funcao->id);

    // Mocka o gate PDR-005 como bloqueado (stub-honesto é sempre true no MVP).
    $this->mock(AvaliacoesPendentesProfissional::class)
        ->shouldReceive('podeCandidatar')->andReturn(false);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")
        ->assertStatus(200)
        ->assertJsonPath('pode_candidatar', false)
        ->assertJsonPath('motivo_bloqueio', 'Avalie seu último turno para se candidatar.');
});

// ───────────────────────── CA-6 — já candidatou ─────────────────────────

test('candidatura pendente → ja_candidatou true + estado pendente (CA-6)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profDet(['funcao_id' => $funcao->id]);
    $vaga = vagaDet($funcao->id);
    Candidatura::factory()->create([
        'vaga_id' => $vaga->id,
        'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Pendente,
    ]);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")
        ->assertStatus(200)
        ->assertJsonPath('ja_candidatou', true)
        ->assertJsonPath('candidatura.estado', 'pendente')
        ->assertJsonStructure(['candidatura' => ['estado', 'criada_em']]);
});

test('candidatura retirada não conta como ja_candidatou (CA-6)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profDet(['funcao_id' => $funcao->id]);
    $vaga = vagaDet($funcao->id);
    Candidatura::factory()->create([
        'vaga_id' => $vaga->id,
        'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Retirada,
    ]);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")
        ->assertJsonPath('ja_candidatou', false)
        ->assertJsonPath('candidatura', null);
});
