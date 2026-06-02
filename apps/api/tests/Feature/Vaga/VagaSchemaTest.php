<?php

// STORY-044 / ADR-013 — conformidade do schema (CA-3, CA-4): tabelas, colunas e
// enums Postgres NATIVOS (não varchar) com os rótulos exatos.

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

uses(RefreshDatabase::class);

test('tabelas do EPIC-002 existem', function () {
    expect(Schema::hasTable('vagas'))->toBeTrue()
        ->and(Schema::hasTable('vaga_versoes'))->toBeTrue()
        ->and(Schema::hasTable('candidaturas'))->toBeTrue()
        ->and(Schema::hasTable('audit_logs'))->toBeTrue();
});

test('vagas tem as colunas materiais e de estado', function () {
    expect(Schema::hasColumns('vagas', [
        'contratante_id', 'funcao_id', 'data_inicio', 'data_fim', 'valor', 'valor_hora',
        'posicoes', 'posicoes_preenchidas', 'observacoes', 'lat', 'lng', 'cidade', 'uf',
        'estado', 'versao_atual', 'publicada_em', 'fechada_em', 'cancelada_em',
    ]))->toBeTrue();
});

test('candidaturas tem colunas de estado, versão e prazos', function () {
    expect(Schema::hasColumns('candidaturas', [
        'vaga_id', 'profissional_id', 'estado', 'vaga_versao_id',
        'revisao_prazo_em', 'aprovada_em', 'retirada_em',
    ]))->toBeTrue();
});

test('vaga_versoes tem snapshot jsonb e não tem updated_at (append-only)', function () {
    expect(Schema::hasColumns('vaga_versoes', ['vaga_id', 'versao', 'snapshot', 'editado_por', 'created_at']))->toBeTrue()
        ->and(Schema::hasColumn('vaga_versoes', 'updated_at'))->toBeFalse();
});

// CA-4 — enums NATIVOS do Postgres, não varchar
test('vaga_estado é enum nativo com os rótulos exatos', function () {
    $labels = collect(DB::select(
        "SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
         WHERE t.typname = 'vaga_estado' ORDER BY e.enumsortorder"
    ))->pluck('enumlabel')->all();

    expect($labels)->toBe(['aberta', 'fechada', 'cancelada']);
});

test('candidatura_estado é enum nativo com os 6 rótulos exatos', function () {
    $labels = collect(DB::select(
        "SELECT e.enumlabel FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
         WHERE t.typname = 'candidatura_estado' ORDER BY e.enumsortorder"
    ))->pluck('enumlabel')->all();

    expect($labels)->toBe([
        'pendente', 'aprovada', 'retirada',
        'pendente_revisao_apos_edicao', 'retirada_por_edicao', 'recusada',
    ]);
});

test('índice parcial do feed existe (CA-8)', function () {
    $idx = collect(DB::select(
        "SELECT indexname FROM pg_indexes WHERE tablename = 'vagas' AND indexname = 'idx_vagas_feed'"
    ));
    expect($idx)->toHaveCount(1);
});
