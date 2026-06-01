<?php

use App\Domain\Cadastro\DocumentoValidator;

// CPFs/CNPJs com dígitos verificadores válidos (fixtures determinísticas).
const CPF_VALIDO = '11144477735';
const CNPJ_VALIDO = '11222333000181';

test('normaliza removendo máscara', function () {
    expect(DocumentoValidator::normalizar('111.444.777-35'))->toBe('11144477735');
    expect(DocumentoValidator::normalizar('11.222.333/0001-81'))->toBe('11222333000181');
});

test('tipoDocumento mapeia tipo_pessoa (PDR-001)', function () {
    expect(DocumentoValidator::tipoDocumento('PF'))->toBe('CPF');
    expect(DocumentoValidator::tipoDocumento('MEI'))->toBe('CNPJ');
    expect(DocumentoValidator::tipoDocumento('PJ'))->toBe('CNPJ');
});

test('CPF válido passa (com e sem máscara)', function () {
    expect(DocumentoValidator::cpfValido(CPF_VALIDO))->toBeTrue();
    expect(DocumentoValidator::cpfValido('111.444.777-35'))->toBeTrue();
});

test('CPF inválido reprova', function (string $cpf) {
    expect(DocumentoValidator::cpfValido($cpf))->toBeFalse();
})->with([
    'dígito errado' => '11144477700',
    'sequência repetida' => '00000000000',
    'curto' => '1114447773',
    'sequência clássica' => '12345678900',
]);

test('CNPJ válido passa (com e sem máscara)', function () {
    expect(DocumentoValidator::cnpjValido(CNPJ_VALIDO))->toBeTrue();
    expect(DocumentoValidator::cnpjValido('11.222.333/0001-81'))->toBeTrue();
});

test('CNPJ inválido reprova', function (string $cnpj) {
    expect(DocumentoValidator::cnpjValido($cnpj))->toBeFalse();
})->with([
    'dígito errado' => '11222333000180',
    'sequência repetida' => '11111111111111',
    'curto' => '1122233300018',
]);

test('validarParaTipoPessoa exige CPF p/ PF e CNPJ p/ MEI/PJ', function () {
    expect(DocumentoValidator::validarParaTipoPessoa('PF', CPF_VALIDO))->toBeTrue();
    expect(DocumentoValidator::validarParaTipoPessoa('PF', CNPJ_VALIDO))->toBeFalse();
    expect(DocumentoValidator::validarParaTipoPessoa('MEI', CNPJ_VALIDO))->toBeTrue();
    expect(DocumentoValidator::validarParaTipoPessoa('PJ', CNPJ_VALIDO))->toBeTrue();
    expect(DocumentoValidator::validarParaTipoPessoa('MEI', CPF_VALIDO))->toBeFalse();
});

test('formata para exibição', function () {
    expect(DocumentoValidator::formatar(CPF_VALIDO, 'CPF'))->toBe('111.444.777-35');
    expect(DocumentoValidator::formatar(CNPJ_VALIDO, 'CNPJ'))->toBe('11.222.333/0001-81');
});
