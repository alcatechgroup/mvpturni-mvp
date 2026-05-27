<?php

use Turni\Domain\Domain;

// CA-10: smoke unitário garantindo que o aparato de teste do Backoffice está plugado.
test('aparato de teste plugado (1 + 1 = 2)', function () {
    expect(1 + 1)->toBe(2);
});

// Mesmo package de domínio compartilhado que o api consome (ADR-002/ADR-003).
test('package de domínio compartilhado está ligado ao admin', function () {
    expect(Domain::bootstrapped())->toBeTrue();
});
