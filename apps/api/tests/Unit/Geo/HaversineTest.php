<?php

// STORY-049 — App\Support\Geo\Haversine: distância reutilizada por feed e detalhe da vaga.

use App\Support\Geo\Haversine;

test('null quando falta geo de qualquer lado', function () {
    expect(Haversine::km(null, -46.6, -23.5, -46.6))->toBeNull();
    expect(Haversine::km(-23.5, null, -23.5, -46.6))->toBeNull();
    expect(Haversine::km(-23.5, -46.6, null, -46.6))->toBeNull();
    expect(Haversine::km(-23.5, -46.6, -23.5, null))->toBeNull();
});

test('mesma coordenada → 0 km', function () {
    expect(Haversine::km(-23.55, -46.63, -23.55, -46.63))->toBe(0.0);
});

test('distância conhecida (~SP↔Campinas ≈ 90 km) com tolerância', function () {
    // São Paulo (-23.55, -46.63) ↔ Campinas (-22.91, -47.06).
    $km = Haversine::km(-23.55, -46.63, -22.91, -47.06);

    expect($km)->toBeGreaterThan(80.0)->toBeLessThan(100.0);
});
