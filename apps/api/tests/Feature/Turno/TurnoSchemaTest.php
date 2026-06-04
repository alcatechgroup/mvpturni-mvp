<?php

// STORY-055 / ADR-015 (CA-2, CA-5) — conformidade do schema de `turnos`: colunas, PK uuid,
// FKs, enum nativo dos 11 estados e os índices exigidos.

use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

test('tabela turnos tem todas as colunas de CA-2', function () {
    $esperadas = [
        'id', 'candidatura_id', 'vaga_id', 'vaga_versao_id', 'profissional_id',
        'contratante_id', 'estabelecimento_id', 'status', 'valor', 'taxa_turni',
        'total_contratante', 'data_inicio', 'data_fim', 'check_in_at', 'check_out_at',
        'geofencing_check_in', 'geofencing_check_out', 'cancelamento',
        'created_at', 'updated_at',
    ];
    foreach ($esperadas as $col) {
        expect(Schema::hasColumn('turnos', $col))->toBeTrue("coluna {$col} ausente");
    }
});

test('PK id é UUID gerado pela aplicação (HasUuids/ADR-018)', function () {
    $turno = Turno::factory()->create();
    expect(Str::isUuid($turno->id))->toBeTrue();
});

test('o tipo turno_status tem exatamente os 11 estados', function () {
    $labels = DB::table('pg_enum')
        ->join('pg_type', 'pg_enum.enumtypid', '=', 'pg_type.oid')
        ->where('pg_type.typname', 'turno_status')
        ->orderBy('pg_enum.enumsortorder')
        ->pluck('enumlabel')
        ->all();

    expect($labels)->toBe([
        'confirmado', 'aguardando_checkin', 'ativo', 'aguardando_checkout', 'em_disputa',
        'finalizado', 'finalizado_ajustado', 'disputa_resolvida_sem_pagamento',
        'cancelado_pro', 'cancelado_emp', 'no_show_pro',
    ]);
});

test('os 3 índices de CA-5 existem', function () {
    $indices = DB::table('pg_indexes')->where('tablename', 'turnos')->pluck('indexname')->all();
    expect($indices)->toContain('idx_turnos_profissional_status')
        ->toContain('idx_turnos_contratante_status')
        ->toContain('idx_turnos_habitualidade');
});

test('jsonb de geofencing e cancelamento faz round-trip', function () {
    $turno = Turno::factory()->create([
        'geofencing_check_in' => ['ok' => false, 'distancia_metros' => 320, 'capturado_em' => now()->toIso8601String(), 'razao' => null],
    ]);
    $fresh = $turno->fresh();
    expect($fresh->geofencing_check_in['ok'])->toBeFalse()
        ->and($fresh->geofencing_check_in['distancia_metros'])->toBe(320);
});
