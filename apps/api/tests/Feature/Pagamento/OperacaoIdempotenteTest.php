<?php

// STORY-056 / ADR-016 (CA-5, CA-10) — NÚCLEO da idempotência. Garante "uma chave = uma
// operação no provedor": clique-duplo no aceite e retry do worker NÃO duplicam o dinheiro.

use App\Domain\Pagamento\Exceptions\PreAutorizacaoNegada;
use App\Domain\Pagamento\OperacaoIdempotente;
use App\Domain\Pagamento\ResultadoOperacao;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Models\PagamentoOperacao;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function resultadoPreAuth(): ResultadoOperacao
{
    return new ResultadoOperacao(
        tipo: TipoOperacaoPagamento::PreAutorizacao,
        status: StatusOperacaoPagamento::Concluida,
        pagarmeOrderId: 'or_x',
        pagarmeChargeId: 'ch_x',
        raw: ['id' => 'or_x', 'charges' => [['id' => 'ch_x']]],
    );
}

test('primeira execução chama o provedor e grava operação concluída', function () {
    $turno = Turno::factory()->create();
    $chamadas = 0;

    $resultado = app(OperacaoIdempotente::class)->executar(
        $turno->id,
        TipoOperacaoPagamento::PreAutorizacao,
        ['total_contratante' => '115.00'],
        function () use (&$chamadas) {
            $chamadas++;

            return resultadoPreAuth();
        },
    );

    expect($chamadas)->toBe(1)
        ->and($resultado->pagarmeChargeId)->toBe('ch_x');

    $op = PagamentoOperacao::where('turno_id', $turno->id)->first();
    expect($op->status)->toBe(StatusOperacaoPagamento::Concluida)
        ->and($op->idempotencia_chave)->toBe('pre_autorizacao:'.$turno->id)
        ->and($op->pagarme_charge_id)->toBe('ch_x')
        ->and($op->request_payload)->toBe(['total_contratante' => '115.00']);
});

test('clique-duplo: segunda execução NÃO chama o provedor e devolve o guardado', function () {
    $turno = Turno::factory()->create();
    $chamadas = 0;
    $operacao = function () use (&$chamadas) {
        $chamadas++;

        return resultadoPreAuth();
    };

    $runner = app(OperacaoIdempotente::class);
    $runner->executar($turno->id, TipoOperacaoPagamento::PreAutorizacao, [], $operacao);
    $segundo = $runner->executar($turno->id, TipoOperacaoPagamento::PreAutorizacao, [], $operacao);

    expect($chamadas)->toBe(1) // o provedor foi chamado UMA vez
        ->and($segundo->pagarmeChargeId)->toBe('ch_x')
        ->and(PagamentoOperacao::where('turno_id', $turno->id)->count())->toBe(1);
});

test('falha de negócio grava status falhou e repassa a exceção', function () {
    $turno = Turno::factory()->create();

    $executar = fn () => app(OperacaoIdempotente::class)->executar(
        $turno->id,
        TipoOperacaoPagamento::PreAutorizacao,
        [],
        fn () => throw new PreAutorizacaoNegada('cartão recusado'),
    );

    expect($executar)->toThrow(PreAutorizacaoNegada::class);

    $op = PagamentoOperacao::where('turno_id', $turno->id)->first();
    expect($op->status)->toBe(StatusOperacaoPagamento::Falhou)
        ->and($op->erro)->toBe('cartão recusado');
});

test('operação falha pode ser reexecutada (worker retenta recuperável)', function () {
    $turno = Turno::factory()->create();
    $runner = app(OperacaoIdempotente::class);

    // 1ª tentativa falha
    try {
        $runner->executar($turno->id, TipoOperacaoPagamento::Captura, [], fn () => throw new PreAutorizacaoNegada('timeout'));
    } catch (PreAutorizacaoNegada) {
    }

    // 2ª tentativa (mesma chave) reexecuta — só `concluida` curto-circuita
    $chamou = false;
    $runner->executar($turno->id, TipoOperacaoPagamento::Captura, [], function () use (&$chamou) {
        $chamou = true;

        return new ResultadoOperacao(TipoOperacaoPagamento::Captura, StatusOperacaoPagamento::Concluida, pagarmeChargeId: 'ch_ok');
    });

    expect($chamou)->toBeTrue()
        ->and(PagamentoOperacao::where('turno_id', $turno->id)->first()->status)
        ->toBe(StatusOperacaoPagamento::Concluida);
});

test('tipos de operação diferentes do mesmo turno coexistem', function () {
    $turno = Turno::factory()->create();
    $runner = app(OperacaoIdempotente::class);

    $runner->executar($turno->id, TipoOperacaoPagamento::PreAutorizacao, [], fn () => resultadoPreAuth());
    $runner->executar($turno->id, TipoOperacaoPagamento::Captura, [], fn () => new ResultadoOperacao(TipoOperacaoPagamento::Captura, StatusOperacaoPagamento::Concluida, pagarmeChargeId: 'ch_x'));

    expect(PagamentoOperacao::where('turno_id', $turno->id)->count())->toBe(2);
});
