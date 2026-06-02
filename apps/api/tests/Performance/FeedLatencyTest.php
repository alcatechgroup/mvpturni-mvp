<?php

// STORY-048 (CA-6) — guarda de performance do feed: com 1k vagas seedadas
// (VagasStressSeeder, ADR-013) e 1 profissional, o p95 de 50 chamadas a GET /api/feed
// fica ≤ 800ms (alvo, non-functional.md). Gate de CI FOLGADO em 1.5× — falha só acima de
// 1200ms; entre 800 e 1200ms loga para análise sem reprovar. Grupo `performance`: roda na
// suíte de pré-push (IDR-004), não a cada salvamento.

use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use Database\Seeders\FuncaoSeeder;
use Database\Seeders\VagasStressSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

// O dir Performance não é vinculado ao TestCase no Pest.php (diferente de Feature/Unit);
// este teste precisa de DB + HTTP, então amarra TestCase + RefreshDatabase explicitamente.
uses(TestCase::class, RefreshDatabase::class);

test('p95 do feed ≤ 800ms (gate 1200ms) com 1k vagas (CA-6)', function () {
    $this->seed(FuncaoSeeder::class);
    $this->seed(VagasStressSeeder::class);

    $funcoes = Funcao::query()->orderBy('id')->take(3)->pluck('id')->all();
    $user = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->create([
        'user_id' => $user->id,
        'funcao_id' => $funcoes[0],
        'funcoes_secundarias' => [$funcoes[1], $funcoes[2]],
        'lat' => -23.55, 'lng' => -46.63, 'raio_max_km' => 50,
    ]);

    $this->actingAs($user);
    $this->getJson('/api/feed')->assertStatus(200); // warmup (aquece opcode/conn)

    $amostras = [];
    for ($i = 0; $i < 50; $i++) {
        $inicio = hrtime(true);
        $this->getJson('/api/feed');
        $amostras[] = (hrtime(true) - $inicio) / 1_000_000;
    }

    sort($amostras);
    $p95 = $amostras[(int) ceil(0.95 * count($amostras)) - 1];

    if ($p95 > 800.0) {
        fwrite(STDERR, sprintf("[FeedLatency] p95=%.1fms acima do alvo de 800ms (gate em 1200ms).\n", $p95));
    }

    expect($p95)->toBeLessThan(1200.0);
})->group('performance');
