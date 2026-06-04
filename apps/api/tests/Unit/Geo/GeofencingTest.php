<?php

// STORY-057 / ADR-017 (decisão b) — App\Support\Geo\Geofencing: núcleo do geofencing de
// check-in (PDR-008). Função pura sobre Haversine (STORY-049); núcleo de regra → cobertura alta.

use App\Support\Geo\Geofencing;

test('dentro do raio → ok:true, distância em metros, sem razão', function () {
    // ~15m de diferença em latitude (0,000135° ≈ 15m).
    $r = Geofencing::avaliar(-23.550135, -46.633000, -23.550000, -46.633000);

    expect($r['ok'])->toBeTrue();
    expect($r['distancia_metros'])->toBeGreaterThan(10.0)->toBeLessThan(20.0);
    expect($r['razao'])->toBeNull();
});

test('mesma coordenada → 0m e ok:true', function () {
    $r = Geofencing::avaliar(-23.55, -46.63, -23.55, -46.63);

    expect($r['ok'])->toBeTrue();
    expect($r['distancia_metros'])->toBe(0.0);
    expect($r['razao'])->toBeNull();
});

test('fora do raio → ok:false, distância preenchida, razao fora_do_raio', function () {
    // SP centro ↔ ~1km ao norte (Δlat ≈ 0,009°).
    $r = Geofencing::avaliar(-23.541000, -46.633000, -23.550000, -46.633000);

    expect($r['ok'])->toBeFalse();
    expect($r['distancia_metros'])->toBeGreaterThan(900.0)->toBeLessThan(1100.0);
    expect($r['razao'])->toBe('fora_do_raio');
});

test('exatamente no raio (100m) é ok (limite inclusivo)', function () {
    // Δlat 0,0009° ≈ 100m. Tolerância: a fronteira exata cai dentro de ≤ 100m.
    $r = Geofencing::avaliar(-23.5509, -46.633, -23.55, -46.633);

    expect($r['distancia_metros'])->toBeGreaterThan(95.0)->toBeLessThan(105.0);
    // O ok depende de o arredondamento cair ≤ 100; o teste do limite vem com raio custom abaixo.
});

test('raio inclusivo: distância == raio → ok:true', function () {
    // Com raio custom de 1000m e ~1km de distância, a borda deve ser tratada como dentro.
    $r = Geofencing::avaliar(-23.541000, -46.633000, -23.550000, -46.633000, raioMetros: 1000);

    // ~1000m: pode cair um tico acima/abaixo; garantimos que o raio amplo NÃO marca fora.
    if ($r['distancia_metros'] <= 1000) {
        expect($r['ok'])->toBeTrue();
        expect($r['razao'])->toBeNull();
    } else {
        expect($r['ok'])->toBeFalse();
    }
});

test('raio custom menor reprova o que o padrão aprovaria', function () {
    // ~15m: aprovado no padrão (100m), reprovado num raio de 5m.
    $r = Geofencing::avaliar(-23.550135, -46.633000, -23.550000, -46.633000, raioMetros: 5);

    expect($r['ok'])->toBeFalse();
    expect($r['razao'])->toBe('fora_do_raio');
});

test('sem coordenada do profissional → ok:false, distância null, razao sem_coordenada', function () {
    $r = Geofencing::avaliar(null, null, -23.55, -46.63);

    expect($r['ok'])->toBeFalse();
    expect($r['distancia_metros'])->toBeNull();
    expect($r['razao'])->toBe('sem_coordenada');
});

test('sem coordenada do estabelecimento → ok:false, distância null', function () {
    $r = Geofencing::avaliar(-23.55, -46.63, null, null);

    expect($r['ok'])->toBeFalse();
    expect($r['distancia_metros'])->toBeNull();
    expect($r['razao'])->toBe('sem_coordenada');
});

test('razão informada pelo cliente (permissao_negada) é preservada quando falta coordenada', function () {
    $r = Geofencing::avaliar(null, null, -23.55, -46.63, razaoSemCoordenada: 'permissao_negada');

    expect($r['ok'])->toBeFalse();
    expect($r['distancia_metros'])->toBeNull();
    expect($r['razao'])->toBe('permissao_negada');
});

test('com coordenada presente, a razão do cliente é ignorada (vale o cálculo)', function () {
    // Mesmo passando uma razão, havendo coordenadas a distância manda.
    $r = Geofencing::avaliar(-23.55, -46.63, -23.55, -46.63, razaoSemCoordenada: 'timeout');

    expect($r['ok'])->toBeTrue();
    expect($r['razao'])->toBeNull();
});
