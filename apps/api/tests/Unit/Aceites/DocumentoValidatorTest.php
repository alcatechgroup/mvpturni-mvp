<?php

// STORY-023 / CA-3 — Validação de CPF (PF) e CNPJ (MEI/PJ) por dígitos verificadores.

use App\Domain\Aceites\DocumentoValidator;

test('CPF válido é aceito (com e sem máscara)', function (string $cpf) {
    expect(DocumentoValidator::valido($cpf, 'PF'))->toBeTrue();
})->with(['52998224725', '529.982.247-25', '111.444.777-35']);

test('CPF inválido é rejeitado', function (string $cpf) {
    expect(DocumentoValidator::valido($cpf, 'PF'))->toBeFalse();
})->with([
    '11111111111',      // todos iguais
    '52998224724',      // dígito verificador errado
    '529982247',        // curto demais
    '5299822472500',    // longo demais
    'abcdefghijk',      // não-numérico
]);

test('CNPJ válido é aceito para MEI e PJ', function (string $tipo) {
    expect(DocumentoValidator::valido('11.222.333/0001-81', $tipo))->toBeTrue();
})->with(['MEI', 'PJ']);

test('CNPJ inválido é rejeitado', function (string $cnpj) {
    expect(DocumentoValidator::valido($cnpj, 'MEI'))->toBeFalse();
})->with([
    '11111111111111',     // todos iguais
    '11222333000180',     // dígito errado
    '1122233300018',      // curto
    '112223330001810',    // longo
]);

test('um CPF válido NÃO passa como CNPJ e vice-versa', function () {
    expect(DocumentoValidator::valido('52998224725', 'MEI'))->toBeFalse(); // CPF no slot de CNPJ
    expect(DocumentoValidator::valido('11222333000181', 'PF'))->toBeFalse(); // CNPJ no slot de CPF
});

test('tipoEsperado mapeia PF→CPF e MEI/PJ→CNPJ', function () {
    expect(DocumentoValidator::tipoEsperado('PF'))->toBe('CPF');
    expect(DocumentoValidator::tipoEsperado('MEI'))->toBe('CNPJ');
    expect(DocumentoValidator::tipoEsperado('PJ'))->toBe('CNPJ');
});

test('formatar aplica máscara de CPF e CNPJ', function () {
    expect(DocumentoValidator::formatar('52998224725', 'PF'))->toBe('529.982.247-25');
    expect(DocumentoValidator::formatar('11222333000181', 'PJ'))->toBe('11.222.333/0001-81');
});

test('normalizar remove tudo que não é dígito', function () {
    expect(DocumentoValidator::normalizar('529.982.247-25'))->toBe('52998224725');
});
