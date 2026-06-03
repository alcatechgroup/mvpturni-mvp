<?php

// STORY-048 — GET /api/feed: feed ranqueado do profissional.
// Cobre CA-1 (shape + RBAC), CA-2 (visibilidade: aberta/função/raio/data futura),
// CA-3 (ordenação por score), CA-4 (filtros), CA-7 (telemetria), CA-8 (gate
// pode_candidatar), CA-9 (cold start) e a paginação (CA-10).

use App\Domain\Avaliacao\AvaliacoesPendentesProfissional;
use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Models\Candidatura;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Log;

uses(RefreshDatabase::class);

/** Profissional ativo com perfil (geo SP + raio amplo por padrão). */
function profFeed(array $perfil = []): User
{
    $user = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->create(array_merge(['user_id' => $user->id], $perfil));

    return $user;
}

/** Vaga aberta futura na Grande SP (dentro do raio padrão do perfil). */
function vagaFeed(string $funcaoId, array $over = []): Vaga
{
    return Vaga::factory()->create(array_merge([
        'funcao_id' => $funcaoId,
        'estado' => VagaEstado::Aberta,
        'data_inicio' => now()->addDays(3),
        'data_fim' => now()->addDays(3)->addHours(6),
        'lat' => -23.55, 'lng' => -46.63,
    ], $over));
}

// ───────────────────────── CA-1 — shape do payload + RBAC ─────────────────────────

test('feed devolve o contrato esperado por vaga (CA-1)', function () {
    $funcao = Funcao::factory()->create(['nome' => 'Garçom']);
    $prof = profFeed(['funcao_id' => $funcao->id]);
    vagaFeed($funcao->id, ['valor' => 150.00]);

    $res = $this->actingAs($prof)->getJson('/api/feed');

    $res->assertStatus(200)
        ->assertJsonStructure([
            'vagas' => [[
                'id', 'funcao', 'data_inicio', 'data_fim', 'valor', 'distancia_km',
                'score' => ['total', 'componentes' => ['funcao', 'distancia', 'historico', 'nivel']],
                'ja_candidatou', 'em_revisao', 'pode_candidatar',
            ]],
            'page', 'has_next',
        ])
        ->assertJsonPath('vagas.0.funcao', 'Garçom')
        ->assertJsonPath('vagas.0.valor', 150)
        ->assertJsonPath('vagas.0.score.componentes.funcao', 40)
        ->assertJsonPath('vagas.0.ja_candidatou', false)
        ->assertJsonPath('vagas.0.pode_candidatar', true)
        ->assertJsonPath('page', 1)
        ->assertJsonPath('has_next', false);
});

test('contratante recebe 403 no feed (RBAC)', function () {
    $contratante = User::factory()->contratante()->ativo()->create();

    $this->actingAs($contratante)->getJson('/api/feed')->assertStatus(403);
});

test('não autenticado recebe 401', function () {
    $this->getJson('/api/feed')->assertStatus(401);
});

test('profissional sem perfil → feed vazio (borda)', function () {
    $user = User::factory()->profissional()->ativo()->create();

    $this->actingAs($user)->getJson('/api/feed')
        ->assertStatus(200)
        ->assertJsonCount(0, 'vagas');
});

// ───────────────────────── CA-2 — visibilidade ─────────────────────────

test('só aparecem vagas abertas, da função, no raio e no futuro (CA-2)', function () {
    $funcao = Funcao::factory()->create();
    $outra = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $funcao->id, 'funcoes_secundarias' => []]);

    $alvo = vagaFeed($funcao->id);

    // ruídos que NÃO devem aparecer
    Vaga::factory()->fechada()->create(['funcao_id' => $funcao->id, 'lat' => -23.55, 'lng' => -46.63]);
    Vaga::factory()->cancelada()->create(['funcao_id' => $funcao->id, 'lat' => -23.55, 'lng' => -46.63]);
    vagaFeed($outra->id); // outra função, não secundária
    vagaFeed($funcao->id, ['data_inicio' => now()->subDays(2), 'data_fim' => now()->subDays(2)->addHours(3)]); // passado

    $res = $this->actingAs($prof)->getJson('/api/feed')->assertStatus(200);

    expect(collect($res->json('vagas'))->pluck('id')->all())->toBe([$alvo->id]);
});

test('função secundária do profissional aparece em "Todas" (CA-2)', function () {
    $primaria = Funcao::factory()->create();
    $secundaria = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $primaria->id, 'funcoes_secundarias' => [$secundaria->id]]);

    vagaFeed($secundaria->id);

    $this->actingAs($prof)->getJson('/api/feed')
        ->assertStatus(200)
        ->assertJsonCount(1, 'vagas')
        ->assertJsonPath('vagas.0.score.componentes.funcao', 25); // secundária = 25
});

// ───────────────────────── CA-3 — ordenação por score ─────────────────────────

test('vagas vêm ordenadas por score decrescente (CA-3)', function () {
    $primaria = Funcao::factory()->create();
    $secundaria = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $primaria->id, 'funcoes_secundarias' => [$secundaria->id]]);

    $vagaSec = vagaFeed($secundaria->id);  // função 25 → score menor
    $vagaPri = vagaFeed($primaria->id);    // função 40 → score maior

    $res = $this->actingAs($prof)->getJson('/api/feed')->assertStatus(200);

    expect(collect($res->json('vagas'))->pluck('id')->all())->toBe([$vagaPri->id, $vagaSec->id]);
});

// ───────────────────────── CA-4 — filtros ─────────────────────────

test('filtro "minha_funcao" restringe à função primária (CA-4)', function () {
    $primaria = Funcao::factory()->create();
    $secundaria = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $primaria->id, 'funcoes_secundarias' => [$secundaria->id]]);

    $vagaPri = vagaFeed($primaria->id);
    vagaFeed($secundaria->id); // não deve aparecer no filtro minha_funcao

    $res = $this->actingAs($prof)->getJson('/api/feed?filtro=minha_funcao')->assertStatus(200);

    expect(collect($res->json('vagas'))->pluck('id')->all())->toBe([$vagaPri->id]);
});

test('filtro "alto_match" só traz score ≥ 80 (CA-4)', function () {
    $primaria = Funcao::factory()->create();
    $secundaria = Funcao::factory()->create();
    // Elite + 4.8★ + raio: primária = 40+20+24+10 = 94 (≥80); secundária = 25+20+24+10 = 79 (<80).
    $prof = profFeed(['funcao_id' => $primaria->id, 'funcoes_secundarias' => [$secundaria->id]]);

    $vagaPri = vagaFeed($primaria->id);
    vagaFeed($secundaria->id);

    $res = $this->actingAs($prof)->getJson('/api/feed?filtro=alto_match')->assertStatus(200);

    expect(collect($res->json('vagas'))->pluck('id')->all())->toBe([$vagaPri->id]);
});

test('filtro "candidatadas" só traz vagas com candidatura ativa (CA-4)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $funcao->id]);

    $comCandidatura = vagaFeed($funcao->id);
    vagaFeed($funcao->id); // sem candidatura → não aparece

    Candidatura::factory()->create([
        'vaga_id' => $comCandidatura->id,
        'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Pendente,
    ]);

    $res = $this->actingAs($prof)->getJson('/api/feed?filtro=candidatadas')->assertStatus(200);

    expect(collect($res->json('vagas'))->pluck('id')->all())->toBe([$comCandidatura->id]);
    $res->assertJsonPath('vagas.0.ja_candidatou', true);
});

test('em_revisao marca o card quando a candidatura está em revisão pós-edição (STORY-052 CA-11)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $funcao->id]);

    $editada = vagaFeed($funcao->id);
    $normal = vagaFeed($funcao->id);
    Candidatura::factory()->create([
        'vaga_id' => $editada->id,
        'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::PendenteRevisaoAposEdicao,
    ]);
    Candidatura::factory()->create([
        'vaga_id' => $normal->id,
        'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::Pendente,
    ]);

    $vagas = collect(
        $this->actingAs($prof)->getJson('/api/feed?filtro=candidatadas')->assertStatus(200)->json('vagas')
    )->keyBy('id');

    expect($vagas[$editada->id]['ja_candidatou'])->toBeTrue()
        ->and($vagas[$editada->id]['em_revisao'])->toBeTrue()
        ->and($vagas[$normal->id]['ja_candidatou'])->toBeTrue()
        ->and($vagas[$normal->id]['em_revisao'])->toBeFalse();
});

test('ja_candidatou reflete candidatura ativa do profissional (CA-1)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $funcao->id]);
    $vaga = vagaFeed($funcao->id);

    // candidatura de OUTRO profissional não marca ja_candidatou para este
    Candidatura::factory()->create(['vaga_id' => $vaga->id, 'estado' => CandidaturaEstado::Pendente]);

    $this->actingAs($prof)->getJson('/api/feed')
        ->assertStatus(200)
        ->assertJsonPath('vagas.0.ja_candidatou', false);
});

// ───────────────────────── CA-8 — gate pode_candidatar ─────────────────────────

test('pode_candidatar = false quando o gate PDR-005 bloqueia (CA-8)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $funcao->id]);
    vagaFeed($funcao->id);

    // Gate que bloqueia (simula turno por avaliar) — o feed continua visível.
    $this->instance(AvaliacoesPendentesProfissional::class, new class extends AvaliacoesPendentesProfissional
    {
        public function podeCandidatar(User $profissional): bool
        {
            return false;
        }
    });

    $this->actingAs($prof)->getJson('/api/feed')
        ->assertStatus(200)
        ->assertJsonCount(1, 'vagas') // visibilidade NÃO é bloqueada (CA-8)
        ->assertJsonPath('vagas.0.pode_candidatar', false);
});

// ───────────────────────── CA-9 — cold start ─────────────────────────

test('profissional sem histórico ainda vê o feed e ranqueia (CA-9)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $funcao->id])->fresh();
    ProfissionalProfile::where('user_id', $prof->id)->update([
        'nivel' => 'Iniciante', 'score' => 0, 'turnos_realizados' => 0,
    ]);
    vagaFeed($funcao->id);

    $res = $this->actingAs($prof)->getJson('/api/feed')->assertStatus(200);

    // Função 40 + distância 20 + histórico 0 + nível 0 = 60.
    $res->assertJsonCount(1, 'vagas')
        ->assertJsonPath('vagas.0.score.total', 60)
        ->assertJsonPath('vagas.0.score.componentes.historico', 0);
});

// ───────────────────────── geo / distância ─────────────────────────

test('sem geo do profissional, distancia_km é null e não filtra por raio', function () {
    $funcao = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $funcao->id, 'lat' => null, 'lng' => null]);
    vagaFeed($funcao->id, ['lat' => -23.55, 'lng' => -46.63]);

    $this->actingAs($prof)->getJson('/api/feed')
        ->assertStatus(200)
        ->assertJsonCount(1, 'vagas')
        ->assertJsonPath('vagas.0.distancia_km', null)
        ->assertJsonPath('vagas.0.score.componentes.distancia', 0);
});

test('vaga dentro do bbox mas fora do raio preciso é filtrada com telemetria (CA-7)', function () {
    Log::spy();
    $funcao = Funcao::factory()->create();
    // Raio pequeno (10km) para que a vaga no canto do bbox caia fora do círculo.
    $prof = profFeed(['funcao_id' => $funcao->id, 'lat' => -23.55, 'lng' => -46.63, 'raio_max_km' => 10]);

    $perto = vagaFeed($funcao->id, ['lat' => -23.55, 'lng' => -46.63]); // ~0 km
    // Dentro do retângulo do bbox, porém ~10,6 km do centro — além do raio de 10 km.
    vagaFeed($funcao->id, ['lat' => -23.48, 'lng' => -46.56]);

    $res = $this->actingAs($prof)->getJson('/api/feed')->assertStatus(200);

    expect(collect($res->json('vagas'))->pluck('id')->all())->toBe([$perto->id]);

    Log::shouldHaveReceived('info')->withArgs(fn (string $e, array $ctx) => $e === 'feed.vaga_filtrada' && $ctx['motivo_filtro'] === 'fora_raio'
    );
});

test('cada vaga retornada dispara feed.vaga_apresentada (CA-7)', function () {
    Log::spy();
    $funcao = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $funcao->id]);
    vagaFeed($funcao->id);

    $this->actingAs($prof)->getJson('/api/feed')->assertStatus(200);

    Log::shouldHaveReceived('info')->withArgs(fn (string $e, array $ctx) => $e === 'feed.vaga_apresentada' && isset($ctx['score_total'], $ctx['componentes'])
    );
});

// ───────────────────────── CA-10 — paginação ─────────────────────────

test('paginação page-based com page size 20 (CA-10)', function () {
    $funcao = Funcao::factory()->create();
    $prof = profFeed(['funcao_id' => $funcao->id]);
    for ($i = 0; $i < 25; $i++) {
        vagaFeed($funcao->id, ['data_inicio' => now()->addDays($i + 2), 'data_fim' => now()->addDays($i + 2)->addHours(6)]);
    }

    $this->actingAs($prof)->getJson('/api/feed?page=1')
        ->assertStatus(200)
        ->assertJsonCount(20, 'vagas')
        ->assertJsonPath('has_next', true);

    $this->actingAs($prof)->getJson('/api/feed?page=2')
        ->assertStatus(200)
        ->assertJsonCount(5, 'vagas')
        ->assertJsonPath('has_next', false);
});
