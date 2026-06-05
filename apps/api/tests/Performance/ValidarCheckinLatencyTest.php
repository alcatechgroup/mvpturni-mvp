<?php

// STORY-062 (CA-4) — guarda de performance da validação do PIN: p95 ≤ 500ms (NFR do
// EPIC-003). Gate de CI FOLGADO em 1.5× — falha só acima de 750ms; entre 500 e 750ms
// loga para análise sem reprovar (mesmo padrão do PainelCandidatosLatencyTest).
// Cada amostra usa um turno PRÓPRIO (a validação transita estado e o rate limit é por
// turno): mede o caminho feliz completo — Hash::check (bcrypt) + transação + audit.
// Grupo `performance`: roda na suíte de pré-push (IDR-004).

use App\Enums\TurnoStatus;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

uses(TestCase::class, RefreshDatabase::class);

test('p95 da validação do PIN ≤ 500ms (gate 750ms) — CA-4', function () {
    $hash = Hash::make('4702'); // mesmo custo bcrypt para todos os turnos

    $turnos = [];
    for ($i = 0; $i < 20; $i++) {
        $turnos[] = Turno::factory()->status(TurnoStatus::AguardandoCheckin)->create([
            'pin_checkin_hash' => $hash,
        ])->fresh(['contratante']);
    }

    // Warmup (rotas/container) — turno descartado da amostra.
    $this->actingAs($turnos[0]->contratante)
        ->postJson("/api/turnos/{$turnos[0]->id}/validar-checkin", ['pin' => '4702'])
        ->assertStatus(200);

    $amostras = [];
    foreach (array_slice($turnos, 1) as $turno) {
        $this->actingAs($turno->contratante);
        $inicio = hrtime(true);
        $this->postJson("/api/turnos/{$turno->id}/validar-checkin", ['pin' => '4702'])
            ->assertStatus(200);
        $amostras[] = (hrtime(true) - $inicio) / 1_000_000;
    }

    sort($amostras);
    $p95 = $amostras[(int) ceil(0.95 * count($amostras)) - 1];

    if ($p95 > 500.0) {
        fwrite(STDERR, sprintf("[ValidarCheckinLatency] p95=%.1fms acima do alvo de 500ms (gate em 750ms).\n", $p95));
    }

    expect($p95)->toBeLessThan(750.0);
})->group('performance');
