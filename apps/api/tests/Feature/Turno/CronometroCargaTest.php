<?php

// STORY-063 (CA-7) — teste de carga do canal do cronômetro: 50 turnos `ativo` simultâneos.
//
// Com ADR-017 o "canal" é o endpoint REST stateless: 50 turnos ativos = 100 clientes
// (2 lados) fazendo polling na janela configurada. Aqui materializamos os 50 turnos e
// disparamos as 100 leituras (profissional + contratante de cada um), medindo a latência
// por request. O CA exige nenhuma latência > 2s; reportamos também o p95 para acompanhar
// degradação antes de estourar o limite. (Sem concorrência real de processo — o gargalo
// medido é o caminho da aplicação: roteamento, RBAC, queries. Latência de rede/Cloud Run
// é coberta pela verificação em homolog do DoD.)

use App\Enums\TurnoStatus;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('50 turnos ativos simultâneos: 100 leituras do cronômetro, todas ≤ 2s (CA-7)', function () {
    $turnos = Turno::factory()
        ->count(50)
        ->status(TurnoStatus::Ativo)
        ->create()
        ->map(fn (Turno $t) => $t->fresh(['profissional', 'contratante']));

    $latenciasMs = [];

    foreach ($turnos as $turno) {
        foreach ([$turno->profissional, $turno->contratante] as $lado) {
            $t0 = hrtime(true);
            $res = $this->actingAs($lado)->getJson("/api/turnos/{$turno->id}/cronometro");
            $latenciasMs[] = (hrtime(true) - $t0) / 1e6;

            $res->assertStatus(200)->assertJsonPath('estado', 'ativo');
        }
    }

    sort($latenciasMs);
    $max = end($latenciasMs);
    $p95 = $latenciasMs[(int) floor(count($latenciasMs) * 0.95)];

    expect(count($latenciasMs))->toBe(100)
        ->and($max)->toBeLessThan(2000.0)   // CA-7: nenhuma leitura acima de 2s
        ->and($p95)->toBeLessThan(500.0);   // guarda de degradação bem antes do limite
});
