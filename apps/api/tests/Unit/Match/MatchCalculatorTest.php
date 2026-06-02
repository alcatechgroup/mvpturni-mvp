<?php

// STORY-045 / ADR-014 (CA-2, CA-3, CA-4). Cobertura 100% da tabela de Match
// (domain/match.md + business-rules.md): Função 40, Distância 20, Histórico 30,
// Nível 10, cap 100. Testes PUROS — sem DB, sem clock.

use App\Domain\Match\EstadoComponente;
use App\Domain\Match\MatchCalculator;
use App\Domain\Match\MatchInput;
use App\Domain\Match\MatchScore;

/**
 * Helper para montar um MatchInput com defaults "neutros" (tudo miss), sobrescrevendo
 * só o que cada teste exercita.
 */
function entrada(
    int $funcaoVagaId = 1,
    int $funcaoPrimariaProfId = 99,
    array $funcoesSecundariasProfIds = [],
    ?float $distanciaKm = null,
    int $raioMaxKm = 8,
    ?float $scoreHistorico = null,
    int $turnosRealizados = 0,
    ?string $nivel = null,
): MatchInput {
    return new MatchInput(
        funcaoVagaId: $funcaoVagaId,
        funcaoPrimariaProfId: $funcaoPrimariaProfId,
        funcoesSecundariasProfIds: $funcoesSecundariasProfIds,
        distanciaKm: $distanciaKm,
        raioMaxKm: $raioMaxKm,
        scoreHistorico: $scoreHistorico,
        turnosRealizados: $turnosRealizados,
        nivel: $nivel,
    );
}

function calcular(MatchInput $i): MatchScore
{
    return (new MatchCalculator)->calcular($i);
}

// ───────────────────────── Função (40 / 25 / 0) ─────────────────────────

test('função primária bate → 40 ok (CA-2)', function () {
    $s = calcular(entrada(funcaoVagaId: 7, funcaoPrimariaProfId: 7));
    expect($s->componentes['funcao'])->toBe(40);
    expect($s->funcao->estado)->toBe(EstadoComponente::Ok);
    expect($s->funcao->pontosMax)->toBe(40);
});

test('função secundária bate → 25 partial (CA-2)', function () {
    $s = calcular(entrada(funcaoVagaId: 5, funcaoPrimariaProfId: 7, funcoesSecundariasProfIds: [3, 5]));
    expect($s->componentes['funcao'])->toBe(25);
    expect($s->funcao->estado)->toBe(EstadoComponente::Partial);
});

test('nenhuma função bate → 0 miss (CA-2)', function () {
    $s = calcular(entrada(funcaoVagaId: 1, funcaoPrimariaProfId: 7, funcoesSecundariasProfIds: [3, 5]));
    expect($s->componentes['funcao'])->toBe(0);
    expect($s->funcao->estado)->toBe(EstadoComponente::Miss);
});

test('primária tem prioridade sobre secundária (borda)', function () {
    // mesmo id na primária e na lista secundária → vale 40 (primária), não 25.
    $s = calcular(entrada(funcaoVagaId: 7, funcaoPrimariaProfId: 7, funcoesSecundariasProfIds: [7]));
    expect($s->componentes['funcao'])->toBe(40);
});

// ───────────────────────── Distância (20 / 0) ─────────────────────────

test('dentro do raio → 20 ok (CA-2)', function () {
    $s = calcular(entrada(distanciaKm: 5.0, raioMaxKm: 8));
    expect($s->componentes['distancia'])->toBe(20);
    expect($s->distancia->estado)->toBe(EstadoComponente::Ok);
});

test('exatamente no limite do raio → 20 ok (borda)', function () {
    $s = calcular(entrada(distanciaKm: 8.0, raioMaxKm: 8));
    expect($s->componentes['distancia'])->toBe(20);
});

test('fora do raio → 0 miss (CA-2)', function () {
    $s = calcular(entrada(distanciaKm: 12.0, raioMaxKm: 8));
    expect($s->componentes['distancia'])->toBe(0);
    expect($s->distancia->estado)->toBe(EstadoComponente::Miss);
});

test('distância indisponível (null) → 0 miss (exceção/borda)', function () {
    $s = calcular(entrada(distanciaKm: null, raioMaxKm: 8));
    expect($s->componentes['distancia'])->toBe(0);
    expect($s->distancia->estado)->toBe(EstadoComponente::Miss);
});

// ───────────────────────── Histórico (linear 4.0★→0 .. 5.0★→30) ─────────────────────────

test('sem histórico (0 turnos) → 0 miss mesmo com score alto (CA-3)', function () {
    $s = calcular(entrada(scoreHistorico: 5.0, turnosRealizados: 0));
    expect($s->componentes['historico'])->toBe(0);
    expect($s->historico->estado)->toBe(EstadoComponente::Miss);
});

test('score 4.0★ → 0 miss (piso do intervalo linear, CA-3)', function () {
    $s = calcular(entrada(scoreHistorico: 4.0, turnosRealizados: 10));
    expect($s->componentes['historico'])->toBe(0);
    expect($s->historico->estado)->toBe(EstadoComponente::Miss);
});

test('score 4.5★ → 15 partial (meio do intervalo, CA-3)', function () {
    $s = calcular(entrada(scoreHistorico: 4.5, turnosRealizados: 10));
    expect($s->componentes['historico'])->toBe(15);
    expect($s->historico->estado)->toBe(EstadoComponente::Partial);
});

test('score 5.0★ → 30 ok (topo do intervalo, CA-3)', function () {
    $s = calcular(entrada(scoreHistorico: 5.0, turnosRealizados: 127));
    expect($s->componentes['historico'])->toBe(30);
    expect($s->historico->estado)->toBe(EstadoComponente::Ok);
});

test('score abaixo de 4.0★ → 0 miss (clamp inferior, borda)', function () {
    $s = calcular(entrada(scoreHistorico: 3.2, turnosRealizados: 4));
    expect($s->componentes['historico'])->toBe(0);
});

test('score acima de 5.0★ → 30 (clamp superior defensivo, borda)', function () {
    $s = calcular(entrada(scoreHistorico: 5.5, turnosRealizados: 4));
    expect($s->componentes['historico'])->toBe(30);
});

// ───────────────────────── Nível (Iniciante/Confiável/Destaque/Elite) ─────────────────────────

test('nível Iniciante → 0 miss (CA-3)', function () {
    $s = calcular(entrada(nivel: 'Iniciante'));
    expect($s->componentes['nivel'])->toBe(0);
    expect($s->nivel->estado)->toBe(EstadoComponente::Miss);
});

test('nível Confiável → 3 partial (CA-3)', function () {
    expect(calcular(entrada(nivel: 'Confiavel'))->componentes['nivel'])->toBe(3);
    // aceita a grafia com acento também
    expect(calcular(entrada(nivel: 'Confiável'))->componentes['nivel'])->toBe(3);
});

test('nível Destaque → 6 partial (CA-3)', function () {
    $s = calcular(entrada(nivel: 'Destaque'));
    expect($s->componentes['nivel'])->toBe(6);
    expect($s->nivel->estado)->toBe(EstadoComponente::Partial);
});

test('nível Elite → 10 ok (CA-3)', function () {
    $s = calcular(entrada(nivel: 'Elite'));
    expect($s->componentes['nivel'])->toBe(10);
    expect($s->nivel->estado)->toBe(EstadoComponente::Ok);
});

test('nível ausente/desconhecido → 0 miss (borda)', function () {
    expect(calcular(entrada(nivel: null))->componentes['nivel'])->toBe(0);
    expect(calcular(entrada(nivel: 'Lendário'))->componentes['nivel'])->toBe(0);
});

// ───────────────────────── Total, cap e breakdown ─────────────────────────

test('combinação máxima soma exatamente 100 (CA-2)', function () {
    $s = calcular(entrada(
        funcaoVagaId: 7, funcaoPrimariaProfId: 7,
        distanciaKm: 2.0, raioMaxKm: 8,
        scoreHistorico: 5.0, turnosRealizados: 127,
        nivel: 'Elite',
    ));
    expect($s->total)->toBe(100);
    expect($s->componentes)->toBe(['funcao' => 40, 'distancia' => 20, 'historico' => 30, 'nivel' => 10]);
});

test('combinação parcial soma corretamente (caminho feliz realista)', function () {
    // secundária (25) + fora do raio (0) + 4.5★ (15) + Confiável (3) = 43
    $s = calcular(entrada(
        funcaoVagaId: 5, funcaoPrimariaProfId: 7, funcoesSecundariasProfIds: [5],
        distanciaKm: 30.0, raioMaxKm: 8,
        scoreHistorico: 4.5, turnosRealizados: 10,
        nivel: 'Confiavel',
    ));
    expect($s->total)->toBe(43);
});

test('breakdown expõe pontos, pontos_max, estado e descrição por componente (CA-2)', function () {
    $s = calcular(entrada(funcaoVagaId: 7, funcaoPrimariaProfId: 7, distanciaKm: 2.0, scoreHistorico: 5.0, turnosRealizados: 5, nivel: 'Elite'));
    $arr = $s->toArray();

    expect($arr)->toHaveKeys(['total', 'componentes', 'breakdown']);
    foreach (['funcao', 'distancia', 'historico', 'nivel'] as $comp) {
        expect($arr['breakdown'][$comp])->toHaveKeys(['pontos', 'pontos_max', 'estado', 'descricao']);
        expect($arr['breakdown'][$comp]['descricao'])->toBeString()->not->toBe('');
        expect($arr['breakdown'][$comp]['estado'])->toBeIn(['ok', 'partial', 'miss']);
    }
});

// ───────────────────────── Pureza / determinismo (CA-4) ─────────────────────────

test('função é determinística — mesma entrada produz mesma saída (CA-4)', function () {
    $in = entrada(funcaoVagaId: 7, funcaoPrimariaProfId: 7, distanciaKm: 3.0, scoreHistorico: 4.8, turnosRealizados: 20, nivel: 'Destaque');
    expect(calcular($in)->toArray())->toEqual(calcular($in)->toArray());
});
