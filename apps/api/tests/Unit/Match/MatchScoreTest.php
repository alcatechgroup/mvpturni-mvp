<?php

// STORY-045 / ADR-014 (CA-3) — invariante de cap. O máximo teórico dos pesos canônicos
// é exatamente 100 (40+20+30+10); o cap é defensivo. Aqui injetamos componentes
// SINTÉTICOS somando 110 direto nos value objects para exercer o clamp (CA-3).

use App\Domain\Match\BreakdownItem;
use App\Domain\Match\EstadoComponente;
use App\Domain\Match\MatchScore;

function item(int $pontos, int $max): BreakdownItem
{
    return new BreakdownItem($pontos, $max, EstadoComponente::Ok, 'sintético');
}

test('componentes acima do máximo são clampados ao seu teto (CA-3)', function () {
    // 44 num componente de máx 40 → 40.
    expect(item(44, 40)->pontos)->toBe(40);
    expect(item(-5, 20)->pontos)->toBe(0); // piso em 0
});

test('total nunca passa de 100 mesmo com componentes somando 110 (CA-3)', function () {
    $score = new MatchScore(
        item(44, 40),  // → 40
        item(22, 20),  // → 20
        item(33, 30),  // → 30
        item(11, 10),  // → 10
    ); // soma bruta pedida = 110

    expect($score->total)->toBe(100);
    expect($score->componentes)->toBe(['funcao' => 40, 'distancia' => 20, 'historico' => 30, 'nivel' => 10]);
});
