<?php

// STORY-044 / ADR-013 Decisão 3 (CA-8) — correção do predicado do feed do profissional:
// função primária + raio (bounding-box) + estado aberta + data futura. O microbenchmark
// EXPLAIN < 100ms é exercido via VagasStressSeeder (registrado na ADR), não aqui.

use App\Enums\VagaEstado;
use App\Models\Funcao;
use App\Models\Vaga;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/** Query candidata do feed (ADR-013 §Plano de verificação). */
function feed(string $funcaoId, array $latRange, array $lngRange)
{
    return Vaga::query()
        ->where('estado', VagaEstado::Aberta)
        ->where('funcao_id', $funcaoId)
        ->where('data_inicio', '>', now())
        ->whereBetween('lat', $latRange)
        ->whereBetween('lng', $lngRange)
        ->pluck('id');
}

test('o feed retorna apenas a vaga que casa todos os critérios', function () {
    $funcao = Funcao::factory()->create();
    $outra = Funcao::factory()->create();

    $alvo = Vaga::factory()->create([
        'funcao_id' => $funcao->id,
        'estado' => VagaEstado::Aberta,
        'data_inicio' => now()->addDays(3),
        'data_fim' => now()->addDays(3)->addHours(6),
        'lat' => -23.55, 'lng' => -46.63,
    ]);

    // ruídos que NÃO devem aparecer
    Vaga::factory()->fechada()->create(['funcao_id' => $funcao->id, 'lat' => -23.55, 'lng' => -46.63]);
    Vaga::factory()->cancelada()->create(['funcao_id' => $funcao->id, 'lat' => -23.55, 'lng' => -46.63]);
    Vaga::factory()->create(['funcao_id' => $outra->id, 'lat' => -23.55, 'lng' => -46.63]); // outra função
    Vaga::factory()->create([ // data no passado
        'funcao_id' => $funcao->id,
        'data_inicio' => now()->subDays(2), 'data_fim' => now()->subDays(2)->addHours(3),
        'lat' => -23.55, 'lng' => -46.63,
    ]);
    Vaga::factory()->create(['funcao_id' => $funcao->id, 'lat' => -10.0, 'lng' => -50.0]); // fora do bbox

    $result = feed($funcao->id, [-23.6, -23.5], [-46.7, -46.6]);

    expect($result->all())->toBe([$alvo->id]);
});

test('vaga exatamente na borda do bounding-box entra', function () {
    $funcao = Funcao::factory()->create();
    $alvo = Vaga::factory()->create([
        'funcao_id' => $funcao->id,
        'data_inicio' => now()->addDay(),
        'data_fim' => now()->addDay()->addHours(4),
        'lat' => -23.6, 'lng' => -46.7, // limites inferiores do range
    ]);

    expect(feed($funcao->id, [-23.6, -23.5], [-46.7, -46.6])->all())->toBe([$alvo->id]);
});
