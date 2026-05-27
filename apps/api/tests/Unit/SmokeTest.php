<?php

use Turni\Domain\Domain;

// CA-10: smoke unitário trivial — só garante que o aparato de teste (Pest, ADR-001)
// está plugado desde a primeira estória.
test('aparato de teste plugado (1 + 1 = 2)', function () {
    expect(1 + 1)->toBe(2);
});

// Prova que o package de domínio compartilhado (packages/domain, ADR-002/ADR-003)
// é carregável e consumível pelo app api via Composer path repository.
test('package de domínio compartilhado está ligado ao api', function () {
    expect(Domain::bootstrapped())->toBeTrue();
    expect(Domain::PACKAGE)->toBe('turni/domain');
});
