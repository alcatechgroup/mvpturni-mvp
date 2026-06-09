<?php

// STORY-085 / ADR-019 Decisão 4 (CA-5) — enum dono dos limiares de nível (niveis-e-score.md:
// 0–499 Iniciante / 500–999 Confiável / 1000–2999 Destaque / 3000+ Elite) e da função
// nivelPara(xp) + ordem (para o high-water-mark do motor). Lógica pura, sem banco.

use App\Enums\NivelProfissional;

test('nivelPara mapeia o XP ao nível pela trilha de niveis-e-score.md', function (int $xp, NivelProfissional $esperado) {
    expect(NivelProfissional::nivelPara($xp))->toBe($esperado);
})->with([
    'piso iniciante' => [0, NivelProfissional::Iniciante],
    'topo iniciante' => [499, NivelProfissional::Iniciante],
    'piso confiável' => [500, NivelProfissional::Confiavel],
    'topo confiável' => [999, NivelProfissional::Confiavel],
    'piso destaque' => [1000, NivelProfissional::Destaque],
    'topo destaque' => [2999, NivelProfissional::Destaque],
    'piso elite' => [3000, NivelProfissional::Elite],
    'muito acima' => [99999, NivelProfissional::Elite],
]);

test('nivelPara trata XP negativo como Iniciante (borda — XP pode ficar negativo)', function () {
    expect(NivelProfissional::nivelPara(-50))->toBe(NivelProfissional::Iniciante);
});

test('ordem é crescente Iniciante < Confiável < Destaque < Elite (para o high-water-mark)', function () {
    expect(NivelProfissional::Iniciante->ordem())->toBeLessThan(NivelProfissional::Confiavel->ordem())
        ->and(NivelProfissional::Confiavel->ordem())->toBeLessThan(NivelProfissional::Destaque->ordem())
        ->and(NivelProfissional::Destaque->ordem())->toBeLessThan(NivelProfissional::Elite->ordem());
});

test('xpAteProximoNivel devolve o que falta para o próximo limiar; null no Elite', function (int $xp, ?int $esperado) {
    expect(NivelProfissional::xpAteProximoNivel($xp))->toBe($esperado);
})->with([
    'iniciante → confiável' => [0, 500],
    'quase confiável' => [499, 1],
    'confiável → destaque' => [510, 490],
    'destaque → elite' => [2999, 1],
    'elite (topo) → null' => [3000, null],
    'muito acima → null' => [9000, null],
    'xp negativo conta do piso de confiável' => [-10, 510],
]);

test('valores do enum batem com os rótulos persistidos no profile', function () {
    expect(NivelProfissional::Iniciante->value)->toBe('Iniciante')
        ->and(NivelProfissional::Confiavel->value)->toBe('Confiavel')
        ->and(NivelProfissional::Destaque->value)->toBe('Destaque')
        ->and(NivelProfissional::Elite->value)->toBe('Elite');
});
