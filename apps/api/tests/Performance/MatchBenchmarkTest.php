<?php

// STORY-045 / ADR-014 (CA-7) — guarda de performance: o cálculo puro de 1k matches
// não pode virar gargalo do feed (p95 ≤ 800ms, non-functional.md). Alvo de projeto
// ≤ 200ms; gate folgado em 500ms (2,5×). Grupo `performance`: roda na suíte de
// pré-push (gate automatizado do projeto — IDR-004), não a cada salvamento.
//
// Construção dos inputs fica FORA da medição — cronometra-se só o cálculo.

use App\Domain\Match\MatchCalculator;
use App\Domain\Match\MatchInput;

test('calcula 1.000 matches em ≤ 500ms (CA-7)', function () {
    $calc = new MatchCalculator;
    $niveis = ['Iniciante', 'Confiavel', 'Destaque', 'Elite'];

    $inputs = [];
    for ($k = 0; $k < 1000; $k++) {
        $inputs[] = new MatchInput(
            funcaoVagaId: $k % 10,
            funcaoPrimariaProfId: $k % 7,
            funcoesSecundariasProfIds: [$k % 5, $k % 3],
            distanciaKm: ($k % 20) + 0.5,
            raioMaxKm: 8,
            scoreHistorico: 4.0 + (($k % 11) / 10),
            turnosRealizados: $k % 200,
            nivel: $niveis[$k % 4],
        );
    }

    $inicio = hrtime(true);
    foreach ($inputs as $in) {
        $calc->calcular($in);
    }
    $ms = (hrtime(true) - $inicio) / 1_000_000;

    expect($ms)->toBeLessThan(500.0);
})->group('performance');
