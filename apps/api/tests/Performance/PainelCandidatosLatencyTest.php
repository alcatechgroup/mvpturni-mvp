<?php

// STORY-051 (CA-8) — guarda de performance do painel de candidatos: uma vaga com 50 candidaturas
// (o teto suportado sem degradação; >100 fica para depois) responde com p95 ≤ 500ms. Gate de CI
// FOLGADO em 1.5× — falha só acima de 750ms; entre 500 e 750ms loga para análise sem reprovar.
// A query é um único SELECT indexado (idx_candidaturas_vaga em (vaga_id, estado)) + eager load do
// perfil — sem N+1. Grupo `performance`: roda na suíte de pré-push (IDR-004).

use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Models\Candidatura;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

uses(TestCase::class, RefreshDatabase::class);

test('p95 do painel ≤ 500ms (gate 750ms) com 50 candidatos (CA-8)', function () {
    $funcao = Funcao::factory()->create();
    $contratante = User::factory()->contratante()->ativo()->create();
    $cnpj = (string) fake()->unique()->numerify('##############');
    ContratanteProfile::create([
        'user_id' => $contratante->id,
        'cnpj_encrypted' => $cnpj,
        'cnpj_hash' => hash_hmac('sha256', $cnpj, (string) config('app.key')),
        'nome_estabelecimento' => 'Bar do Zé Ltda',
        'apelido_estabelecimento' => 'Bar do Zé',
        'cidade' => 'São Paulo',
    ]);
    $vaga = Vaga::factory()->create([
        'contratante_id' => $contratante->id,
        'funcao_id' => $funcao->id,
        'estado' => VagaEstado::Aberta,
        'data_inicio' => now()->addDays(3),
        'data_fim' => now()->addDays(3)->addHours(6),
    ]);

    // 50 candidatos com perfil + snapshot persistido (o painel não recalcula — CA-2/CA-4).
    for ($i = 0; $i < 50; $i++) {
        $prof = User::factory()->profissional()->ativo()->create();
        ProfissionalProfile::factory()->create([
            'user_id' => $prof->id, 'funcao_id' => $funcao->id,
            'nivel' => 'Elite', 'score' => 4.80,
        ]);
        Candidatura::factory()->create([
            'vaga_id' => $vaga->id, 'profissional_id' => $prof->id,
            'estado' => CandidaturaEstado::Pendente,
            'score_no_momento' => random_int(40, 99),
            'score_breakdown' => [
                'total' => 90,
                'componentes' => ['funcao' => 40, 'distancia' => 20, 'historico' => 20, 'nivel' => 10],
                'breakdown' => [
                    'funcao' => ['pontos' => 40, 'pontos_max' => 40, 'estado' => 'ok', 'descricao' => 'x'],
                    'distancia' => ['pontos' => 20, 'pontos_max' => 20, 'estado' => 'ok', 'descricao' => 'x'],
                    'historico' => ['pontos' => 20, 'pontos_max' => 30, 'estado' => 'partial', 'descricao' => 'x'],
                    'nivel' => ['pontos' => 10, 'pontos_max' => 10, 'estado' => 'ok', 'descricao' => 'x'],
                ],
            ],
        ]);
    }

    $this->actingAs($contratante);
    $this->getJson("/api/vagas/{$vaga->id}/candidatos")
        ->assertStatus(200)
        ->assertJsonPath('total', 50); // warmup + sanidade

    $amostras = [];
    for ($i = 0; $i < 50; $i++) {
        $inicio = hrtime(true);
        $this->getJson("/api/vagas/{$vaga->id}/candidatos");
        $amostras[] = (hrtime(true) - $inicio) / 1_000_000;
    }

    sort($amostras);
    $p95 = $amostras[(int) ceil(0.95 * count($amostras)) - 1];

    if ($p95 > 500.0) {
        fwrite(STDERR, sprintf("[PainelLatency] p95=%.1fms acima do alvo de 500ms (gate em 750ms).\n", $p95));
    }

    expect($p95)->toBeLessThan(750.0);
})->group('performance');
