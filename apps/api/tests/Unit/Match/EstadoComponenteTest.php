<?php

// STORY-045 / ADR-014 — estados visuais de cada componente do breakdown (CA-2).

use App\Domain\Match\EstadoComponente;

test('rótulos do enum batem com o contrato do breakdown (CA-2)', function () {
    expect(array_map(fn ($c) => $c->value, EstadoComponente::cases()))
        ->toBe(['ok', 'partial', 'miss']);
});
