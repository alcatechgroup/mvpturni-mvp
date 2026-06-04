<?php

// STORY-055 / ADR-015 — relações e casts do model Turno.

use App\Enums\TurnoStatus;
use App\Models\AceiteEletronicoTurno;
use App\Models\Candidatura;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('relações do turno resolvem', function () {
    $turno = Turno::factory()->create();
    AceiteEletronicoTurno::factory()->create(['turno_id' => $turno->id]);

    expect($turno->candidatura)->toBeInstanceOf(Candidatura::class)
        ->and($turno->vaga)->toBeInstanceOf(Vaga::class)
        ->and($turno->profissional)->toBeInstanceOf(User::class)
        ->and($turno->contratante)->toBeInstanceOf(User::class)
        ->and($turno->estabelecimento)->toBeInstanceOf(User::class)
        ->and($turno->aceite)->toBeInstanceOf(AceiteEletronicoTurno::class)
        ->and($turno->aceites)->toHaveCount(1);
});

test('vaga_versao_id é opcional e resolve quando presente', function () {
    $vaga = Vaga::factory()->create();
    $versao = VagaVersao::factory()->create(['vaga_id' => $vaga->id]);
    $turno = Turno::factory()->create(['vaga_id' => $vaga->id, 'vaga_versao_id' => $versao->id]);

    expect($turno->vagaVersao)->toBeInstanceOf(VagaVersao::class);
});

test('estabelecimento = contratante no MVP (mesma referência)', function () {
    $turno = Turno::factory()->create();
    expect($turno->estabelecimento_id)->toBe($turno->contratante_id);
});

test('casts: status é TurnoStatus, financeiro decimal, jsonb é array', function () {
    $turno = Turno::factory()->status(TurnoStatus::Ativo)->create([
        'geofencing_check_in' => ['ok' => true, 'distancia_metros' => 12],
    ]);
    $fresh = $turno->fresh();

    expect($fresh->status)->toBeInstanceOf(TurnoStatus::class)
        ->and($fresh->geofencing_check_in)->toBeArray()
        ->and($fresh->check_in_at)->not->toBeNull();
});
