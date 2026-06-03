<?php

// STORY-069 — CA-1 — Validação empírica do UUIDv7 (ADR-018, Decisão 1 e 6).
//
// Descoberta do spike: em Laravel 13.x o trait first-class é `HasUuids`, que JÁ
// gera UUIDv7 por padrão (`Str::uuid7()`). NÃO existe trait `HasVersion7Uuids`
// nesta versão (referência da ADR-018 corrigida). Para v4 ordenado existiria
// `HasVersion4Uuids` (`Str::orderedUuid()`), que NÃO é o que queremos.
//
// Este teste exercita o caminho real do Eloquent: um model temporário que usa
// `HasUuids` e gera o id via `newUniqueId()` — exatamente o que os models de
// domínio farão na STORY-070.

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

/**
 * Model temporário só para o teste — exercita o trait real sem tocar no banco.
 */
class _Ca1TempModel extends Model
{
    use HasUuids;
}

/** Extrai a versão (nibble após o 2º hífen) de um UUID textual. */
function ca1_version(string $uuid): int
{
    return (int) hexdec($uuid[14]);
}

/** Extrai os 48 bits altos (timestamp em ms, RFC 9562) de um UUIDv7. */
function ca1_timestamp_ms(string $uuid): int
{
    $hex = str_replace('-', '', $uuid);

    return (int) hexdec(substr($hex, 0, 12));
}

test('CA-1: HasUuids gera UUIDv7 válido, ordenável e sem colisão (1000 amostras)', function () {
    $model = new _Ca1TempModel;
    $n = 1000;

    /** @var list<string> $ids */
    $ids = [];
    for ($i = 0; $i < $n; $i++) {
        $ids[] = $model->newUniqueId();
    }

    expect($ids)->toHaveCount($n);

    // (a) todos são UUIDv7 e formato UUID válido.
    foreach ($ids as $id) {
        expect(Str::isUuid($id))->toBeTrue("'$id' não é UUID válido");
        expect(ca1_version($id))->toBe(7, "'$id' não é versão 7");
    }

    // (c) zero colisões.
    expect(array_unique($ids))->toHaveCount($n, 'houve colisão de UUID em 1000 amostras');

    // (b) ordenação: o timestamp embutido é monotônico não-decrescente na ordem
    // de geração (v7 carrega ms nos 48 bits altos). Empates no mesmo ms são
    // tolerados — não exigimos monotonicidade sub-ms.
    $tsGen = array_map('ca1_timestamp_ms', $ids);
    $tsGenSorted = $tsGen;
    sort($tsGenSorted);
    expect($tsGen)->toBe($tsGenSorted, 'timestamps não são monotônicos na ordem de geração');

    // E o sort lexical da string produz a mesma ordem cronológica (ms): para
    // qualquer par, ordenar as strings nunca inverte o timestamp.
    $byString = $ids;
    usort($byString, fn ($a, $b) => strcmp($a, $b));
    $tsByString = array_map('ca1_timestamp_ms', $byString);
    $tsByStringSorted = $tsByString;
    sort($tsByStringSorted);
    expect($tsByString)->toBe($tsByStringSorted, 'sort lexical não preserva ordem cronológica de ms');
});
