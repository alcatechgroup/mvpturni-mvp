<?php

// STORY-052 — detector de edição material + diff (PDR-009). Lógica pura, sem banco.
// Cobre CA-2 (detecção campo-a-campo) e a forma do diff que alimenta CA-3/CA-10/CA-11.

use App\Domain\Vaga\EdicaoMaterial;

/** @return array<string,mixed> */
function payloadMaterial(array $over = []): array
{
    return array_merge([
        'funcao_id' => 1,
        'data_inicio' => '2026-06-12T18:00:00-03:00',
        'data_fim' => '2026-06-12T23:00:00-03:00',
        'valor' => 120.00,
        'posicoes' => 2,
        'observacoes' => 'Levar avental.',
    ], $over);
}

test('payload idêntico → sem diff → edição não material (CA-2/CA-5)', function () {
    $a = EdicaoMaterial::snapshotDePayload(payloadMaterial());
    $b = EdicaoMaterial::snapshotDePayload(payloadMaterial());

    expect(EdicaoMaterial::diff($a, $b))->toBe([]);
    expect(EdicaoMaterial::ehMaterial($a, $b))->toBeFalse();
});

test('mudança de valor → 1 linha de diff material com antes/depois (CA-2/CA-3)', function () {
    $a = EdicaoMaterial::snapshotDePayload(payloadMaterial());
    $b = EdicaoMaterial::snapshotDePayload(payloadMaterial(['valor' => 150.00]));

    $diff = EdicaoMaterial::diff($a, $b);

    expect($diff)->toHaveCount(1);
    expect($diff[0]['campo'])->toBe('valor');
    expect($diff[0]['tipo'])->toBe('valor');
    expect($diff[0]['antes'])->toBe(120.00);
    expect($diff[0]['depois'])->toBe(150.00);
    expect(EdicaoMaterial::ehMaterial($a, $b))->toBeTrue();
});

test('observação null e string vazia/só-espaço são equivalentes (não material)', function () {
    $a = EdicaoMaterial::snapshotDePayload(payloadMaterial(['observacoes' => null]));
    $b = EdicaoMaterial::snapshotDePayload(payloadMaterial(['observacoes' => '   ']));

    expect(EdicaoMaterial::diff($a, $b))->toBe([]);
});

test('observação com texto diferente é material (PDR-009 — texto que afeta expectativa)', function () {
    $a = EdicaoMaterial::snapshotDePayload(payloadMaterial(['observacoes' => 'Avental preto.']));
    $b = EdicaoMaterial::snapshotDePayload(payloadMaterial(['observacoes' => 'Avental branco.']));

    $diff = EdicaoMaterial::diff($a, $b);
    expect($diff)->toHaveCount(1)->and($diff[0]['campo'])->toBe('observacoes');
});

test('mesma data em fusos/representações diferentes não é mudança', function () {
    $a = EdicaoMaterial::snapshotDePayload(payloadMaterial(['data_inicio' => '2026-06-12T18:00:00-03:00']));
    $b = EdicaoMaterial::snapshotDePayload(payloadMaterial(['data_inicio' => '2026-06-12T21:00:00+00:00']));

    expect(EdicaoMaterial::diff($a, $b))->toBe([]);
});

test('várias mudanças vêm na ordem canônica de CAMPOS', function () {
    $a = EdicaoMaterial::snapshotDePayload(payloadMaterial());
    $b = EdicaoMaterial::snapshotDePayload(payloadMaterial([
        'observacoes' => 'Outra coisa.',
        'valor' => 200.00,
        'posicoes' => 5,
        'funcao_id' => 9,
    ]));

    $campos = array_map(fn ($l) => $l['campo'], EdicaoMaterial::diff($a, $b));

    // ordem de EdicaoMaterial::CAMPOS: funcao_id, data_inicio, data_fim, valor, posicoes, observacoes
    expect($campos)->toBe(['funcao_id', 'valor', 'posicoes', 'observacoes']);
});

test('diff de data devolve ISO-8601 e diff de função devolve os ids (resolvidos a nome na borda)', function () {
    $a = EdicaoMaterial::snapshotDePayload(payloadMaterial());
    $b = EdicaoMaterial::snapshotDePayload(payloadMaterial([
        'data_inicio' => '2026-06-12T19:00:00-03:00',
        'funcao_id' => 7,
    ]));

    $diff = collect(EdicaoMaterial::diff($a, $b))->keyBy('campo');

    expect($diff['data_inicio']['depois'])->toContain('2026-06-12T19:00:00');
    expect($diff['funcao_id']['antes'])->toBe(1);
    expect($diff['funcao_id']['depois'])->toBe(7);
});
