<?php

// STORY-024 CA-4 — Busca de endereço por CEP (ViaCEP), fail-soft: qualquer falha da API
// externa retorna null (não bloqueia o submit) e loga falha de integração. IDR-024.

use App\Domain\Cadastro\CepLookup;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

beforeEach(function () {
    config()->set('services.viacep.base_url', 'https://viacep.com.br/ws');
    config()->set('services.viacep.timeout', 4);
});

// (a) caminho feliz
test('CA-4: CEP válido retorna endereço mapeado', function () {
    Http::fake(['viacep.com.br/*' => Http::response([
        'cep' => '01001-000',
        'logradouro' => 'Praça da Sé',
        'bairro' => 'Sé',
        'localidade' => 'São Paulo',
        'uf' => 'SP',
    ], 200)]);

    $endereco = app(CepLookup::class)->buscar('01001-000');

    expect($endereco)->toBe([
        'cep' => '01001-000',
        'logradouro' => 'Praça da Sé',
        'bairro' => 'Sé',
        'cidade' => 'São Paulo',
        'uf' => 'SP',
    ]);
});

test('CA-4: aceita CEP com máscara ou só dígitos (normaliza antes de chamar)', function () {
    Http::fake(['viacep.com.br/*' => Http::response([
        'logradouro' => 'Praça da Sé', 'bairro' => 'Sé', 'localidade' => 'São Paulo', 'uf' => 'SP',
    ], 200)]);

    app(CepLookup::class)->buscar('01001000');

    Http::assertSent(fn ($req) => str_contains($req->url(), '01001000/json'));
});

// (b) caso inválido — CEP malformado não chega a chamar a API
test('CA-4: CEP malformado (≠8 dígitos) retorna null sem chamar a API', function () {
    Http::fake();

    expect(app(CepLookup::class)->buscar('123'))->toBeNull();
    expect(app(CepLookup::class)->buscar('abcdefgh'))->toBeNull();
    Http::assertNothingSent();
});

// (b) CEP inexistente — ViaCEP responde {"erro": true}
test('CA-4: CEP inexistente (erro do ViaCEP) retorna null', function () {
    Http::fake(['viacep.com.br/*' => Http::response(['erro' => true], 200)]);

    expect(app(CepLookup::class)->buscar('99999999'))->toBeNull();
});

// (c) exceção esperada — timeout/indisponibilidade não lança; loga e degrada
test('CA-4: falha da API externa não lança, retorna null e loga falha de integração', function () {
    Http::fake(fn () => throw new ConnectionException('timeout'));
    Log::spy();

    expect(app(CepLookup::class)->buscar('01001000'))->toBeNull();

    Log::shouldHaveReceived('warning')
        ->withArgs(fn ($msg) => $msg === 'cadastro.cep_lookup_falhou')
        ->once();
});

// (c) status 5xx do ViaCEP também degrada para null
test('CA-4: status de erro HTTP do ViaCEP retorna null', function () {
    Http::fake(['viacep.com.br/*' => Http::response('', 500)]);

    expect(app(CepLookup::class)->buscar('01001000'))->toBeNull();
});

// (d) borda — string vazia
test('CA-4: CEP vazio retorna null sem chamar a API', function () {
    Http::fake();

    expect(app(CepLookup::class)->buscar(''))->toBeNull();
    Http::assertNothingSent();
});
