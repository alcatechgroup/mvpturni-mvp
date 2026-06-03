<?php

// STORY-052 CA-9 — cron `candidaturas:auto-retirar-apos-edicao` (PDR-009).
// Retira candidaturas em revisão cujo prazo (24h ou início do turno) estourou; idempotente.

use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Models\AuditLog;
use App\Models\Candidatura;
use App\Models\Funcao;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function vagaFuturaCron(array $over = []): Vaga
{
    $func = Funcao::firstOrCreate(['slug' => 'garcom'], ['nome' => 'Garçom', 'ativo' => true]);
    $dono = User::factory()->contratante()->ativo()->create();

    return Vaga::factory()->create(array_merge([
        'contratante_id' => $dono->id, 'funcao_id' => $func->id,
        'estado' => VagaEstado::Aberta,
        'data_inicio' => now()->addDays(3), 'data_fim' => now()->addDays(3)->addHours(5),
    ], $over));
}

test('candidatura com prazo estourado é auto-retirada (CA-9)', function () {
    $vaga = vagaFuturaCron();
    $cand = Candidatura::factory()->create([
        'vaga_id' => $vaga->id,
        'estado' => CandidaturaEstado::PendenteRevisaoAposEdicao,
        'revisao_prazo_em' => now()->subMinute(),
    ]);

    $this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful();

    expect($cand->fresh()->estado)->toBe(CandidaturaEstado::RetiradaPorEdicao);
    expect(AuditLog::where('action', 'candidatura.retirada_por_edicao_auto')->where('target_id', $cand->id)->count())->toBe(1);
});

test('candidatura é auto-retirada porque o turno já começou, mesmo com prazo à frente (CA-9)', function () {
    // turno no passado (vaga já começou); prazo carimbado ainda no futuro.
    $vaga = vagaFuturaCron(['data_inicio' => now()->subHour(), 'data_fim' => now()->addHours(4)]);
    $cand = Candidatura::factory()->create([
        'vaga_id' => $vaga->id,
        'estado' => CandidaturaEstado::PendenteRevisaoAposEdicao,
        'revisao_prazo_em' => now()->addHours(5),
    ]);

    $this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful();

    expect($cand->fresh()->estado)->toBe(CandidaturaEstado::RetiradaPorEdicao);
});

test('candidatura dentro do prazo NÃO é tocada', function () {
    $vaga = vagaFuturaCron();
    $cand = Candidatura::factory()->create([
        'vaga_id' => $vaga->id,
        'estado' => CandidaturaEstado::PendenteRevisaoAposEdicao,
        'revisao_prazo_em' => now()->addHours(10),
    ]);

    $this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful();

    expect($cand->fresh()->estado)->toBe(CandidaturaEstado::PendenteRevisaoAposEdicao);
    expect(AuditLog::where('action', 'candidatura.retirada_por_edicao_auto')->count())->toBe(0);
});

test('candidatura pendente normal não é afetada pelo cron', function () {
    $vaga = vagaFuturaCron();
    $cand = Candidatura::factory()->create([
        'vaga_id' => $vaga->id, 'estado' => CandidaturaEstado::Pendente,
        'revisao_prazo_em' => null,
    ]);

    $this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful();

    expect($cand->fresh()->estado)->toBe(CandidaturaEstado::Pendente);
});

test('cron é idempotente: rodar duas vezes não duplica retirada nem audit', function () {
    $vaga = vagaFuturaCron();
    $cand = Candidatura::factory()->create([
        'vaga_id' => $vaga->id,
        'estado' => CandidaturaEstado::PendenteRevisaoAposEdicao,
        'revisao_prazo_em' => now()->subMinute(),
    ]);

    $this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful();
    $this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful();

    expect($cand->fresh()->estado)->toBe(CandidaturaEstado::RetiradaPorEdicao);
    expect(AuditLog::where('action', 'candidatura.retirada_por_edicao_auto')->where('target_id', $cand->id)->count())->toBe(1);
});
