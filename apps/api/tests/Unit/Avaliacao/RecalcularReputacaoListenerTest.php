<?php

// STORY-085 / ADR-019 Decisão 3 (CA-4) — o listener síncrono do motor. O caminho feliz
// (dispara → motor recomputa) é coberto pelo RegistrarAvaliacaoTest (via endpoint); aqui
// trava o branch defensivo: avaliadoId desconhecido = no-op (não derruba a transação).

use App\Enums\TurnoStatus;
use App\Events\AvaliacaoRegistrada;
use App\Models\Avaliacao;
use App\Models\ProfissionalProfile;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

test('AvaliacaoRegistrada com avaliado desconhecido é no-op (defensivo)', function () {
    // Não lança e não toca em profile algum.
    AvaliacaoRegistrada::dispatch((string) Str::uuid7(), (string) Str::uuid7(), (string) Str::uuid7());
})->throwsNoExceptions();

test('AvaliacaoRegistrada recomputa a reputação do avaliado (caminho do listener)', function () {
    $pro = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->coldStart()->create(['user_id' => $pro->id]);
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create(['profissional_id' => $pro->id]);
    $avaliacao = Avaliacao::factory()->paraTurno($turno)->estrelas(5)->create();

    AvaliacaoRegistrada::dispatch($avaliacao->id, $pro->id, $turno->id);

    expect($pro->profissionalProfile->fresh()->xp)->toBe(40); // 30 turno + 10 (5★)
});
