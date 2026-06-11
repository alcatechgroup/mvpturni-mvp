<?php

// STORY-096 (CA-3/CA-4) / IDR-032 — cliente do canal service-to-service admin→api do comando
// "pagar integral". O admin é CLIENTE: a captura+Pix é single-sourced na api (ADR-020 Decisão 3).
// O cliente envia o segredo (X-Internal-Token) + admin_id + nota_admin e MAPEIA as respostas:
//   200          → Ok (resolvido)
//   422 estado_invalido → Concorrente (turno já saiu de em_disputa — outro admin resolveu)
//   demais/erro de rede → Erro (genérico, sem efeito duplicado)

use App\Services\Disputas\ResolverDisputaClient;
use App\Services\Disputas\ResultadoResolucao;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

beforeEach(function () {
    config()->set('services.api.internal_url', 'http://api.test');
    config()->set('services.internal.token', 'segredo-de-teste');
});

function cliente(): ResolverDisputaClient
{
    return app(ResolverDisputaClient::class);
}

// ── Caminho feliz ───────────────────────────────────────────────────────────
test('CA-3: 200 da api → Ok; envia X-Internal-Token, admin_id e nota_admin no endpoint interno', function () {
    Http::fake([
        'http://api.test/api/internal/turnos/*/resolver-disputa' => Http::response(['estado' => 'finalizado'], 200),
    ]);

    $resultado = cliente()->resolver('turno-1', 'admin-9', 'Justificativa procede; pagar integral.');

    expect($resultado)->toBe(ResultadoResolucao::Ok);

    Http::assertSent(function ($request) {
        return $request->url() === 'http://api.test/api/internal/turnos/turno-1/resolver-disputa'
            && $request->method() === 'POST'
            && $request->hasHeader('X-Internal-Token', 'segredo-de-teste')
            && $request['admin_id'] === 'admin-9'
            && $request['nota_admin'] === 'Justificativa procede; pagar integral.';
    });
});

// ── Caminho alternativo: concorrência (CA-4) ─────────────────────────────────
test('CA-4: 422 estado_invalido → Concorrente (turno já resolvido por outro admin)', function () {
    Http::fake([
        '*' => Http::response(['motivo' => 'estado_invalido', 'estado' => 'finalizado'], 422),
    ]);

    expect(cliente()->resolver('t', 'a', 'nota'))->toBe(ResultadoResolucao::Concorrente);
});

// ── Exceções/erros (CA-4) ────────────────────────────────────────────────────
test('CA-4: 403 (admin inválido) → Erro', function () {
    Http::fake(['*' => Http::response('', 403)]);
    expect(cliente()->resolver('t', 'a', 'nota'))->toBe(ResultadoResolucao::Erro);
});

test('CA-4: 401 (segredo divergente) → Erro', function () {
    Http::fake(['*' => Http::response('', 401)]);
    expect(cliente()->resolver('t', 'a', 'nota'))->toBe(ResultadoResolucao::Erro);
});

test('CA-4: 422 com outro motivo (nota_admin_obrigatoria) → Erro, não Concorrente', function () {
    Http::fake(['*' => Http::response(['motivo' => 'nota_admin_obrigatoria'], 422)]);
    expect(cliente()->resolver('t', 'a', 'nota'))->toBe(ResultadoResolucao::Erro);
});

test('CA-4: 500 da api → Erro', function () {
    Http::fake(['*' => Http::response('', 500)]);
    expect(cliente()->resolver('t', 'a', 'nota'))->toBe(ResultadoResolucao::Erro);
});

test('CA-4: erro de conexão (api fora do ar) → Erro, sem propagar exceção', function () {
    Http::fake(function () {
        throw new ConnectionException('connection refused');
    });
    expect(cliente()->resolver('t', 'a', 'nota'))->toBe(ResultadoResolucao::Erro);
});

test('CA-4: erro inesperado (Throwable genérico) → Erro, sem propagar exceção', function () {
    Http::fake(function () {
        throw new RuntimeException('algo inesperado');
    });
    expect(cliente()->resolver('t', 'a', 'nota'))->toBe(ResultadoResolucao::Erro);
});

// ── Borda: token não configurado ─────────────────────────────────────────────
test('borda: token ausente na config → Erro sem fazer request (fail-secure)', function () {
    config()->set('services.internal.token', '');
    Http::fake();

    expect(cliente()->resolver('t', 'a', 'nota'))->toBe(ResultadoResolucao::Erro);
    Http::assertNothingSent();
});
