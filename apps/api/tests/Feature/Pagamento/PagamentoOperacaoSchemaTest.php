<?php

// STORY-056 / ADR-016 (CA-5) — invariantes de banco da pagamento_operacoes: índice único
// (turno_id, tipo_operacao) como barreira de não-duplicação + CHECK de tipo/status.

use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Models\PagamentoOperacao;
use App\Models\Turno;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function novaOperacao(Turno $turno, TipoOperacaoPagamento $tipo): PagamentoOperacao
{
    return PagamentoOperacao::create([
        'turno_id' => $turno->id,
        'tipo_operacao' => $tipo,
        'idempotencia_chave' => $tipo->chaveIdempotente($turno->id),
        'status' => StatusOperacaoPagamento::Pendente,
    ]);
}

test('id é UUID e turno_id resolve a relação (ADR-018)', function () {
    $turno = Turno::factory()->create();
    $op = novaOperacao($turno, TipoOperacaoPagamento::PreAutorizacao);

    expect($op->id)->toMatch('/^[0-9a-f-]{36}$/')
        ->and($op->turno->id)->toBe($turno->id);
});

test('(turno_id, tipo_operacao) é único — recusa a duplicação', function () {
    $turno = Turno::factory()->create();
    novaOperacao($turno, TipoOperacaoPagamento::PreAutorizacao);

    expect(fn () => novaOperacao($turno, TipoOperacaoPagamento::PreAutorizacao))
        ->toThrow(QueryException::class);
});

test('idempotencia_chave é única', function () {
    $turno = Turno::factory()->create();
    novaOperacao($turno, TipoOperacaoPagamento::Captura);

    expect(fn () => PagamentoOperacao::create([
        'turno_id' => $turno->id,
        'tipo_operacao' => TipoOperacaoPagamento::Liberacao,
        'idempotencia_chave' => TipoOperacaoPagamento::Captura->chaveIdempotente($turno->id), // colide de propósito
        'status' => StatusOperacaoPagamento::Pendente,
    ]))->toThrow(QueryException::class);
});

test('CHECK recusa tipo_operacao fora do enum', function () {
    $turno = Turno::factory()->create();

    expect(fn () => DB::table('pagamento_operacoes')->insert([
        'id' => Str::uuid7()->toString(),
        'turno_id' => $turno->id,
        'tipo_operacao' => 'inventado',
        'idempotencia_chave' => 'x:'.$turno->id,
        'status' => 'pendente',
    ]))->toThrow(QueryException::class);
});

test('CHECK recusa status fora do enum', function () {
    $turno = Turno::factory()->create();

    expect(fn () => DB::table('pagamento_operacoes')->insert([
        'id' => Str::uuid7()->toString(),
        'turno_id' => $turno->id,
        'tipo_operacao' => 'captura',
        'idempotencia_chave' => 'captura:'.$turno->id,
        'status' => 'voando',
    ]))->toThrow(QueryException::class);
});

test('casts: tipo/status são enums, payloads são array', function () {
    $turno = Turno::factory()->create();
    $op = PagamentoOperacao::create([
        'turno_id' => $turno->id,
        'tipo_operacao' => TipoOperacaoPagamento::Pix,
        'idempotencia_chave' => 'pix:'.$turno->id,
        'status' => StatusOperacaoPagamento::Concluida,
        'request_payload' => ['valor' => '100.00'],
        'response_payload' => ['id' => 'tr_1'],
    ]);
    $fresh = $op->fresh();

    expect($fresh->tipo_operacao)->toBe(TipoOperacaoPagamento::Pix)
        ->and($fresh->status)->toBe(StatusOperacaoPagamento::Concluida)
        ->and($fresh->request_payload)->toBe(['valor' => '100.00'])
        ->and($fresh->concluida())->toBeTrue();
});
