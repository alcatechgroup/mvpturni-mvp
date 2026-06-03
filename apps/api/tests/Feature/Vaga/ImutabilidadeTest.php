<?php

// STORY-044 / ADR-013 (CA-5, Decisão 1 e 5) — imutabilidade append-only de
// vaga_versoes e audit_logs garantida no banco (trigger + REVOKE), padrão ADR-010.

use App\Models\AuditLog;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

// ── vaga_versoes ──
test('vaga_versoes aceita INSERT', function () {
    $versao = VagaVersao::factory()->create();
    expect($versao->id)->toBeString();
    expect(Str::isUuid($versao->id))->toBeTrue();
});

test('vaga_versoes é imutável — UPDATE (SQL) lança exceção do banco', function () {
    $versao = VagaVersao::factory()->create();
    expect(fn () => DB::statement('UPDATE vaga_versoes SET versao = 99 WHERE id = ?', [$versao->id]))
        ->toThrow(Exception::class);
});

test('vaga_versoes é imutável — DELETE (SQL) lança exceção do banco', function () {
    $versao = VagaVersao::factory()->create();
    expect(fn () => DB::statement('DELETE FROM vaga_versoes WHERE id = ?', [$versao->id]))
        ->toThrow(Exception::class);
});

test('vaga_versoes — Eloquent update() lança exceção', function () {
    $versao = VagaVersao::factory()->create();
    expect(fn () => $versao->update(['versao' => 99]))->toThrow(Exception::class);
});

test('vaga_versoes — versão é única por vaga', function () {
    $vaga = Vaga::factory()->create();
    VagaVersao::factory()->create(['vaga_id' => $vaga->id, 'versao' => 1]);

    expect(fn () => VagaVersao::factory()->create(['vaga_id' => $vaga->id, 'versao' => 1]))
        ->toThrow(Exception::class);
});

// ── audit_logs ──
test('audit_logs aceita INSERT', function () {
    $log = AuditLog::create([
        'actor_id' => User::factory()->contratante()->ativo()->create()->id,
        'action' => 'vaga.criada',
        'target_type' => 'Vaga',
        'target_id' => (string) Str::uuid7(),
        'payload' => ['posicoes' => 2],
    ]);
    expect($log->id)->toBeString();
    expect(Str::isUuid($log->id))->toBeTrue();
});

test('audit_logs é imutável — UPDATE lança exceção', function () {
    $log = AuditLog::create(['action' => 'vaga.criada']);
    expect(fn () => DB::statement('UPDATE audit_logs SET action = ? WHERE id = ?', ['x', $log->id]))
        ->toThrow(Exception::class);
});

test('audit_logs é imutável — DELETE lança exceção', function () {
    $log = AuditLog::create(['action' => 'vaga.criada']);
    expect(fn () => DB::statement('DELETE FROM audit_logs WHERE id = ?', [$log->id]))
        ->toThrow(Exception::class);
});
