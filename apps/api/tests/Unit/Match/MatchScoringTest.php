<?php

// STORY-045 / ADR-014 (CA-2) — adapter que monta o MatchInput a partir das entidades
// de domínio (ProfissionalProfile + Vaga) e da distância já computada pela query do
// feed. Usa instâncias NÃO persistidas: o adapter só lê atributos hidratados, sem
// tocar o banco (preserva a pureza do cálculo — CA-4).

use App\Domain\Match\MatchScoring;
use App\Models\ProfissionalProfile;
use App\Models\Vaga;

function profissional(array $attrs = []): ProfissionalProfile
{
    return new ProfissionalProfile(array_merge([
        'funcao_id' => 7,
        'funcoes_secundarias' => [3, 5],
        'score' => 5.0,
        'turnos_realizados' => 50,
        'nivel' => 'Elite',
        'raio_max_km' => 8,
    ], $attrs));
}

function vaga(array $attrs = []): Vaga
{
    return new Vaga(array_merge(['funcao_id' => 7], $attrs));
}

test('monta o input a partir das entidades e devolve o score esperado (CA-2)', function () {
    $score = (new MatchScoring)->paraEntidades(profissional(), vaga(), distanciaKm: 2.0);

    // primária (40) + dentro do raio (20) + 5.0★ (30) + Elite (10) = 100
    expect($score->total)->toBe(100);
});

test('função secundária da entidade conta como 25 (CA-2)', function () {
    $score = (new MatchScoring)->paraEntidades(
        profissional(['funcao_id' => 99]),     // primária não bate
        vaga(['funcao_id' => 5]),              // mas 5 está nas secundárias [3,5]
        distanciaKm: 50.0,                     // fora do raio
    );

    expect($score->componentes['funcao'])->toBe(25);
    expect($score->componentes['distancia'])->toBe(0);
});

test('profissional sem histórico nem nível pontua só função/distância (borda)', function () {
    $score = (new MatchScoring)->paraEntidades(
        profissional(['score' => null, 'turnos_realizados' => 0, 'nivel' => null, 'funcoes_secundarias' => []]),
        vaga(),
        distanciaKm: 1.0,
    );

    expect($score->componentes)->toBe(['funcao' => 40, 'distancia' => 20, 'historico' => 0, 'nivel' => 0]);
    expect($score->total)->toBe(60);
});

test('distância nula (geo indisponível) zera só a distância (exceção)', function () {
    $score = (new MatchScoring)->paraEntidades(profissional(), vaga(), distanciaKm: null);

    expect($score->componentes['distancia'])->toBe(0);
    expect($score->total)->toBe(80); // 40 + 0 + 30 + 10
});
