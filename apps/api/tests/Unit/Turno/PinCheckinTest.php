<?php

// STORY-061 (CA-3) — núcleo da geração do PIN de check-in: 4 dígitos, uniforme via
// random_int, com retry para evitar PINs triviais (4 dígitos repetidos ou sequência
// ascendente/descendente de passo 1) — decisão documentada na estória (o CA marcava como
// opcional; implementado porque o custo é uma rejeição rara e o ganho é PIN menos chutável).

use App\Domain\Turno\PinCheckin;

// ── (a) caminho feliz ────────────────────────────────────────────────────────

test('gerar devolve sempre 4 dígitos como string (preserva zeros à esquerda)', function () {
    foreach (range(1, 200) as $i) {
        $pin = PinCheckin::gerar();
        expect($pin)->toMatch('/^\d{4}$/');
    }
});

test('gerar com fonte injetada devolve o valor formatado', function () {
    $pin = PinCheckin::gerar(fn () => 42);

    expect($pin)->toBe('0042');
});

// ── (b) inválidos — a tabela-verdade do trivial ──────────────────────────────

test('ehTrivial reconhece os 10 PINs de dígitos repetidos', function () {
    foreach (range(0, 9) as $d) {
        expect(PinCheckin::ehTrivial(str_repeat((string) $d, 4)))->toBeTrue();
    }
});

test('ehTrivial reconhece sequências ascendentes e descendentes de passo 1', function () {
    foreach (['0123', '1234', '2345', '3456', '4567', '5678', '6789'] as $pin) {
        expect(PinCheckin::ehTrivial($pin))->toBeTrue("esperava {$pin} trivial");
    }
    foreach (['9876', '8765', '7654', '6543', '5432', '4321', '3210'] as $pin) {
        expect(PinCheckin::ehTrivial($pin))->toBeTrue("esperava {$pin} trivial");
    }
});

test('ehTrivial NÃO marca PINs comuns não-triviais', function () {
    foreach (['0042', '1123', '4702', '9081', '2468', '1357', '1122', '0110'] as $pin) {
        expect(PinCheckin::ehTrivial($pin))->toBeFalse("esperava {$pin} não-trivial");
    }
});

// ── (c) exceção esperada — fonte só devolve trivial ──────────────────────────

test('gerar estoura após esgotar as tentativas se a fonte só devolve triviais', function () {
    PinCheckin::gerar(fn () => 1111);
})->throws(RuntimeException::class);

// ── (d) bordas ───────────────────────────────────────────────────────────────

test('gerar re-sorteia quando a fonte devolve trivial e aceita o próximo válido', function () {
    $valores = [1234, 0, 4702]; // 1234 (sequência) e 0000 (repetido) caem; 4702 passa
    $pin = PinCheckin::gerar(function () use (&$valores) {
        return array_shift($valores);
    });

    expect($pin)->toBe('4702');
});

test('gerar nunca devolve trivial com a fonte real (amostragem)', function () {
    foreach (range(1, 500) as $i) {
        expect(PinCheckin::ehTrivial(PinCheckin::gerar()))->toBeFalse();
    }
});

test('distribuição da fonte real cobre o range (sanidade de uniformidade)', function () {
    $vistos = [];
    foreach (range(1, 300) as $i) {
        $vistos[(int) PinCheckin::gerar()] = true;
    }

    // 300 sorteios em [0,9999]: colisão total (1 único valor) indicaria fonte quebrada.
    expect(count($vistos))->toBeGreaterThan(250);
});
