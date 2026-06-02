<?php

// STORY-051 — GET /api/vagas/{vaga}/candidatos: painel de candidatos do contratante.
// Cobre CA-1 (contrato + RBAC dono/profissional/404), CA-2 (ordenação score DESC, candidatou_em
// ASC — sem recalcular), CA-3 (campos do profissional: função primária, nível, score histórico),
// CA-4 (score_breakdown = snapshot persistido, não recalculado), CA-5 (alerta_habitualidade),
// CA-7 (vaga sem candidatos → lista vazia) e CA-9 (cenários de cobertura).

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

/** Contratante ativo com estabelecimento (o modelo não tem factory). */
function pcContratante(array $perfil = []): User
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
        'plano' => 'member_start',
    ], $perfil));

    return $contratante;
}

/** Vaga aberta do contratante informado. */
function pcVaga(int $contratanteId, int $funcaoId, array $over = []): Vaga
{
    return Vaga::factory()->create(array_merge([
        'contratante_id' => $contratanteId,
        'funcao_id' => $funcaoId,
        'estado' => VagaEstado::Aberta,
        'data_inicio' => now()->addDays(3)->setTime(18, 0),
        'data_fim' => now()->addDays(3)->setTime(23, 0),
        'valor' => 150.00,
        'cidade' => 'São Paulo',
    ], $over));
}

/** Profissional ativo com perfil (função + nível + score). */
function pcProf(int $funcaoId, array $perfil = []): User
{
    $user = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->create(array_merge([
        'user_id' => $user->id,
        'funcao_id' => $funcaoId,
        'nivel' => 'Elite',
        'score' => 4.90,
    ], $perfil));

    return $user;
}

/** Candidatura pendente com snapshot de score. */
function pcCandidatura(Vaga $vaga, User $prof, int $score, array $over = []): Candidatura
{
    return Candidatura::factory()->create(array_merge([
        'vaga_id' => $vaga->id,
        'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Pendente,
        'score_no_momento' => $score,
        'score_breakdown' => [
            'total' => $score,
            'componentes' => ['funcao' => 40, 'distancia' => 20, 'historico' => 22, 'nivel' => 10],
            'breakdown' => [
                'funcao' => ['pontos' => 40, 'pontos_max' => 40, 'estado' => 'ok', 'descricao' => 'Função primária bate'],
                'distancia' => ['pontos' => 20, 'pontos_max' => 20, 'estado' => 'ok', 'descricao' => 'A 2 km'],
                'historico' => ['pontos' => 22, 'pontos_max' => 30, 'estado' => 'partial', 'descricao' => 'Média 4,9'],
                'nivel' => ['pontos' => 10, 'pontos_max' => 10, 'estado' => 'ok', 'descricao' => 'Elite na trilha'],
            ],
        ],
    ], $over));
}

// ───────────────────────── CA-1 — contrato + RBAC ─────────────────────────

test('contratante dono recebe os candidatos com o contrato completo (CA-1)', function () {
    $funcao = Funcao::factory()->create(['nome' => 'Garçom']);
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);
    $prof = pcProf($funcao->id, ['nivel' => 'Elite', 'score' => 4.90]);
    pcCandidatura($vaga, $prof, 92);

    $res = $this->actingAs($dono)->getJson("/api/vagas/{$vaga->id}/candidatos");

    $res->assertStatus(200)
        ->assertJsonStructure([
            'total',
            'candidatos' => [[
                'id',
                'profissional' => ['id', 'nome', 'foto_url', 'funcao_primaria', 'nivel', 'score_historico', 'plano'],
                'score_no_momento', 'score_breakdown' => ['total', 'componentes', 'breakdown'],
                'candidatou_em', 'alerta_habitualidade',
            ]],
        ])
        ->assertJsonPath('total', 1)
        ->assertJsonPath('candidatos.0.profissional.id', $prof->id)
        ->assertJsonPath('candidatos.0.profissional.funcao_primaria', 'Garçom')
        ->assertJsonPath('candidatos.0.profissional.nivel', 'Elite')
        ->assertJsonPath('candidatos.0.profissional.score_historico', 4.9)
        ->assertJsonPath('candidatos.0.profissional.plano', null)
        ->assertJsonPath('candidatos.0.score_no_momento', 92)
        ->assertJsonPath('candidatos.0.alerta_habitualidade', false);
});

test('contratante não-dono recebe 403 (RBAC — CA-1)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $outro = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);

    $this->actingAs($outro)->getJson("/api/vagas/{$vaga->id}/candidatos")->assertStatus(403);
});

test('profissional recebe 403 (RBAC — CA-1)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);
    $prof = pcProf($funcao->id);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/candidatos")->assertStatus(403);
});

test('não autenticado recebe 401', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);

    $this->getJson("/api/vagas/{$vaga->id}/candidatos")->assertStatus(401);
});

test('vaga inexistente → 404 (CA-1)', function () {
    $dono = pcContratante();

    $this->actingAs($dono)->getJson('/api/vagas/999999/candidatos')->assertStatus(404);
});

// ───────────────────────── CA-7 — vaga sem candidatos ─────────────────────────

test('vaga sem candidatos → lista vazia e total 0 (CA-7)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);

    $this->actingAs($dono)->getJson("/api/vagas/{$vaga->id}/candidatos")
        ->assertStatus(200)
        ->assertJsonPath('total', 0)
        ->assertJsonPath('candidatos', []);
});

// ───────────────────────── CA-2 — ordenação ─────────────────────────

test('candidatos vêm ordenados por score DESC (CA-2)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);

    $baixo = pcProf($funcao->id);
    $alto = pcProf($funcao->id);
    $medio = pcProf($funcao->id);
    pcCandidatura($vaga, $baixo, 71);
    pcCandidatura($vaga, $alto, 92);
    pcCandidatura($vaga, $medio, 88);

    $res = $this->actingAs($dono)->getJson("/api/vagas/{$vaga->id}/candidatos")->assertStatus(200);

    $scores = array_column($res->json('candidatos'), 'score_no_momento');
    expect($scores)->toBe([92, 88, 71]);
});

test('empate de score desempata por candidatou_em ASC (CA-2)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);

    $primeiro = pcProf($funcao->id);
    $segundo = pcProf($funcao->id);
    pcCandidatura($vaga, $primeiro, 80, ['created_at' => now()->subHours(2)]);
    pcCandidatura($vaga, $segundo, 80, ['created_at' => now()->subHour()]);

    $res = $this->actingAs($dono)->getJson("/api/vagas/{$vaga->id}/candidatos")->assertStatus(200);

    $ids = array_map(fn ($c) => $c['profissional']['id'], $res->json('candidatos'));
    expect($ids)->toBe([$primeiro->id, $segundo->id]);
});

test('5 candidatos retornam na ordem correta (CA-9)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);

    $scores = [55, 99, 73, 88, 40];
    foreach ($scores as $s) {
        pcCandidatura($vaga, pcProf($funcao->id), $s);
    }

    $res = $this->actingAs($dono)->getJson("/api/vagas/{$vaga->id}/candidatos")->assertStatus(200);
    expect($res->json('total'))->toBe(5)
        ->and(array_column($res->json('candidatos'), 'score_no_momento'))->toBe([99, 88, 73, 55, 40]);
});

// ───────────────────────── CA-4 — snapshot não recalculado ─────────────────────────

test('score_breakdown devolvido é o snapshot persistido, não recalculado (CA-4)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);
    $prof = pcProf($funcao->id);
    pcCandidatura($vaga, $prof, 92);

    $this->actingAs($dono)->getJson("/api/vagas/{$vaga->id}/candidatos")
        ->assertStatus(200)
        ->assertJsonPath('candidatos.0.score_breakdown.total', 92)
        ->assertJsonPath('candidatos.0.score_breakdown.breakdown.funcao.pontos', 40)
        ->assertJsonPath('candidatos.0.score_breakdown.breakdown.funcao.estado', 'ok')
        ->assertJsonPath('candidatos.0.score_breakdown.breakdown.historico.estado', 'partial');
});

// ───────────────────────── CA-5 — alerta de habitualidade ─────────────────────────

test('alerta_habitualidade true aparece no payload (CA-5)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);
    $prof = pcProf($funcao->id);
    pcCandidatura($vaga, $prof, 85, ['alerta_habitualidade' => true]);

    $this->actingAs($dono)->getJson("/api/vagas/{$vaga->id}/candidatos")
        ->assertStatus(200)
        ->assertJsonPath('candidatos.0.alerta_habitualidade', true);
});

// ───────────────────────── borda — só candidatos vivos/pendentes ─────────────────────────

test('candidatura retirada não aparece no painel (borda)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);
    $ativo = pcProf($funcao->id);
    $saiu = pcProf($funcao->id);
    pcCandidatura($vaga, $ativo, 90);
    pcCandidatura($vaga, $saiu, 95, ['estado' => CandidaturaEstado::Retirada]);

    $res = $this->actingAs($dono)->getJson("/api/vagas/{$vaga->id}/candidatos")->assertStatus(200);
    expect($res->json('total'))->toBe(1)
        ->and($res->json('candidatos.0.profissional.id'))->toBe($ativo->id);
});

test('candidatos de outra vaga não vazam para o painel (borda)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vagaA = pcVaga($dono->id, $funcao->id);
    $vagaB = pcVaga($dono->id, $funcao->id);
    pcCandidatura($vagaA, pcProf($funcao->id), 90);
    pcCandidatura($vagaB, pcProf($funcao->id), 80);

    $this->actingAs($dono)->getJson("/api/vagas/{$vagaA->id}/candidatos")
        ->assertStatus(200)
        ->assertJsonPath('total', 1);
});

// ───────────────────────── snapshot legado nulo (fail-soft) ─────────────────────────

test('profissional com foto_path devolve o campo foto_url sem quebrar a listagem (borda — fail-soft)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);
    $prof = pcProf($funcao->id, ['foto_path' => 'profissionais/fotos/abc.jpg']);
    pcCandidatura($vaga, $prof, 90);

    $res = $this->actingAs($dono)->getJson("/api/vagas/{$vaga->id}/candidatos")->assertStatus(200);
    // Disco privado não serve URL no MVP → fail-soft para null; o importante é não quebrar e ter o campo.
    expect($res->json('candidatos.0.profissional'))->toHaveKey('foto_url');
});

test('candidatura sem score_breakdown persistido devolve null sem quebrar (borda)', function () {
    $funcao = Funcao::factory()->create();
    $dono = pcContratante();
    $vaga = pcVaga($dono->id, $funcao->id);
    $prof = pcProf($funcao->id);
    Candidatura::factory()->create([
        'vaga_id' => $vaga->id, 'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Pendente,
        'score_no_momento' => null, 'score_breakdown' => null,
    ]);

    $this->actingAs($dono)->getJson("/api/vagas/{$vaga->id}/candidatos")
        ->assertStatus(200)
        ->assertJsonPath('total', 1)
        ->assertJsonPath('candidatos.0.score_breakdown', null)
        ->assertJsonPath('candidatos.0.score_no_momento', null);
});
