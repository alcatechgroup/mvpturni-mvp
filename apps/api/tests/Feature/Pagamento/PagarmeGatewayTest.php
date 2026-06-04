<?php

// STORY-056 / ADR-016 (CA-3, CA-10) — adapter Pagar.me. Http::fake garante 0 rede. Cobre:
// shape do request (external_reference UUID, Idempotency-Key, capture=false, centavos), parsing
// do response e o mapa de erro HTTP → exceção de domínio (Decisão 3A).

use App\Domain\Pagamento\Exceptions\CapturaFalhou;
use App\Domain\Pagamento\Exceptions\GatewayIndisponivel;
use App\Domain\Pagamento\Exceptions\LiberacaoFalhou;
use App\Domain\Pagamento\Exceptions\PixFalhou;
use App\Domain\Pagamento\Exceptions\PreAutorizacaoNegada;
use App\Domain\Pagamento\GatewayPagamento;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Models\PagamentoOperacao;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

uses(RefreshDatabase::class);

beforeEach(function () {
    config()->set('services.pagarme.base_url', 'http://pagarme-mock:8080');
    config()->set('services.pagarme.secret_key', 'sk_test');
});

function gateway(): GatewayPagamento
{
    return app(GatewayPagamento::class);
}

test('pré-autorização envia external_reference, Idempotency-Key e capture=false, em centavos', function () {
    $turnoId = '0190abc-uuid';
    Http::fake(['*/orders' => Http::response(['id' => 'or_1', 'charges' => [['id' => 'ch_1', 'status' => 'authorized']]])]);

    $resultado = gateway()->preAutorizar($turnoId, '115.50', 'tok_abc');

    expect($resultado->tipo)->toBe(TipoOperacaoPagamento::PreAutorizacao)
        ->and($resultado->status)->toBe(StatusOperacaoPagamento::Concluida)
        ->and($resultado->pagarmeOrderId)->toBe('or_1')
        ->and($resultado->pagarmeChargeId)->toBe('ch_1');

    Http::assertSent(function ($request) use ($turnoId) {
        return str_ends_with($request->url(), '/orders')
            && $request['amount'] === 11550
            && $request['external_reference'] === $turnoId
            && $request['capture'] === false
            && $request['payment_token'] === 'tok_abc'
            && $request->hasHeader('Idempotency-Key', "pre_autorizacao:{$turnoId}");
    });
});

test('captura usa o charge_id correlacionado da pré-autorização do turno', function () {
    $turno = Turno::factory()->create();
    PagamentoOperacao::create([
        'turno_id' => $turno->id,
        'tipo_operacao' => TipoOperacaoPagamento::PreAutorizacao,
        'idempotencia_chave' => 'pre_autorizacao:'.$turno->id,
        'status' => StatusOperacaoPagamento::Concluida,
        'pagarme_charge_id' => 'ch_corr',
    ]);
    Http::fake(['*/charges/ch_corr/capture' => Http::response(['id' => 'ch_corr', 'status' => 'paid'])]);

    $resultado = gateway()->capturar($turno->id);

    expect($resultado->pagarmeChargeId)->toBe('ch_corr');
    Http::assertSent(fn ($r) => str_ends_with($r->url(), '/charges/ch_corr/capture')
        && $r->hasHeader('Idempotency-Key', 'captura:'.$turno->id));
});

test('captura sem pré-autorização correlacionada falha como CapturaFalhou', function () {
    $turno = Turno::factory()->create();
    Http::fake();

    expect(fn () => gateway()->capturar($turno->id))->toThrow(CapturaFalhou::class);
    Http::assertNothingSent();
});

test('liberação chama cancel no charge correlacionado', function () {
    $turno = Turno::factory()->create();
    PagamentoOperacao::create([
        'turno_id' => $turno->id,
        'tipo_operacao' => TipoOperacaoPagamento::PreAutorizacao,
        'idempotencia_chave' => 'pre_autorizacao:'.$turno->id,
        'status' => StatusOperacaoPagamento::Concluida,
        'pagarme_charge_id' => 'ch_lib',
    ]);
    Http::fake(['*/charges/ch_lib/cancel' => Http::response(['id' => 'ch_lib', 'status' => 'canceled'])]);

    $resultado = gateway()->liberar($turno->id);

    expect($resultado->tipo)->toBe(TipoOperacaoPagamento::Liberacao);
    Http::assertSent(fn ($r) => str_ends_with($r->url(), '/charges/ch_lib/cancel'));
});

test('captura parcial envia amount ajustado no charge correlacionado (EPIC-005)', function () {
    $turno = Turno::factory()->create();
    PagamentoOperacao::create([
        'turno_id' => $turno->id,
        'tipo_operacao' => TipoOperacaoPagamento::PreAutorizacao,
        'idempotencia_chave' => 'pre_autorizacao:'.$turno->id,
        'status' => StatusOperacaoPagamento::Concluida,
        'pagarme_charge_id' => 'ch_par',
    ]);
    Http::fake(['*/charges/ch_par/capture' => Http::response(['id' => 'ch_par', 'status' => 'paid', 'amount' => 9000])]);

    $resultado = gateway()->capturarParcial($turno->id, '90.00');

    expect($resultado->tipo)->toBe(TipoOperacaoPagamento::CapturaParcial);
    Http::assertSent(fn ($r) => str_ends_with($r->url(), '/charges/ch_par/capture')
        && $r['amount'] === 9000
        && $r->hasHeader('Idempotency-Key', 'captura_parcial:'.$turno->id));
});

test('4xx em captura vira CapturaFalhou; 4xx em liberação vira LiberacaoFalhou', function () {
    $turno = Turno::factory()->create();
    PagamentoOperacao::create([
        'turno_id' => $turno->id,
        'tipo_operacao' => TipoOperacaoPagamento::PreAutorizacao,
        'idempotencia_chave' => 'pre_autorizacao:'.$turno->id,
        'status' => StatusOperacaoPagamento::Concluida,
        'pagarme_charge_id' => 'ch_e',
    ]);

    Http::fake(['*/charges/ch_e/capture' => Http::response(['message' => 'já capturado'], 409)]);
    expect(fn () => gateway()->capturar($turno->id))->toThrow(CapturaFalhou::class);

    Http::fake(['*/charges/ch_e/cancel' => Http::response(['message' => 'não cancelável'], 422)]);
    expect(fn () => gateway()->liberar($turno->id))->toThrow(LiberacaoFalhou::class);
});

test('Pix envia amount, pix_key e external_reference; retorna transfer_id', function () {
    $turnoId = '0190-pix';
    Http::fake(['*/transfers' => Http::response(['id' => 'tr_9', 'status' => 'paid'])]);

    $resultado = gateway()->transferirPix($turnoId, '100.00', 'chave-pix-secreta@x.com');

    expect($resultado->pagarmeTransferId)->toBe('tr_9')
        ->and($resultado->tipo)->toBe(TipoOperacaoPagamento::Pix);
    Http::assertSent(fn ($r) => str_ends_with($r->url(), '/transfers')
        && $r['amount'] === 10000
        && $r['pix_key'] === 'chave-pix-secreta@x.com'
        && $r['external_reference'] === $turnoId);
});

test('4xx em pré-autorização vira PreAutorizacaoNegada (fatal) com a mensagem do provedor', function () {
    Http::fake(['*/orders' => Http::response(['message' => 'cartão sem limite'], 422)]);

    expect(fn () => gateway()->preAutorizar('t1', '50.00', 'tok'))
        ->toThrow(PreAutorizacaoNegada::class, 'cartão sem limite');
});

test('4xx em Pix vira PixFalhou (fatal — PDR-010 uma tentativa)', function () {
    Http::fake(['*/transfers' => Http::response(['message' => 'chave inválida'], 400)]);

    expect(fn () => gateway()->transferirPix('t1', '50.00', 'chave-ruim'))
        ->toThrow(PixFalhou::class);
});

test('5xx vira GatewayIndisponivel (recuperável — worker retenta)', function () {
    Http::fake(['*/orders' => Http::response('erro', 503)]);

    try {
        gateway()->preAutorizar('t1', '50.00', 'tok');
        $this->fail('esperava GatewayIndisponivel');
    } catch (GatewayIndisponivel $e) {
        expect($e->recuperavel)->toBeTrue();
    }
});

test('falha de conexão vira GatewayIndisponivel', function () {
    Http::fake(fn () => throw new ConnectionException('connection refused'));

    expect(fn () => gateway()->preAutorizar('t1', '50.00', 'tok'))->toThrow(GatewayIndisponivel::class);
});

test('conversão para centavos é exata sem ponto flutuante', function () {
    $casos = ['0.01' => 1, '0.10' => 10, '1.00' => 100, '115.50' => 11550, '999.99' => 99999, '7' => 700];

    foreach ($casos as $decimal => $centavosEsperado) {
        Http::fake(['*/transfers' => Http::response(['id' => 'tr_x', 'status' => 'paid'])]);
        gateway()->transferirPix('t-'.$centavosEsperado, (string) $decimal, 'k');
        Http::assertSent(fn ($r) => str_ends_with($r->url(), '/transfers') && $r['amount'] === $centavosEsperado);
    }
});
