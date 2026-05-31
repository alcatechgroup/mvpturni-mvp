<?php

// STORY-023 / CA-4 — Validação básica de chave Pix (tipo + formato).

use App\Domain\Aceites\ChavePixValidator;

test('detecta o tipo correto para cada chave Pix válida', function (string $chave, string $tipo) {
    expect(ChavePixValidator::valida($chave))->toBeTrue();
    expect(ChavePixValidator::tipo($chave))->toBe($tipo);
})->with([
    'cpf' => ['52998224725', 'cpf'],
    'cnpj' => ['11222333000181', 'cnpj'],
    'email' => ['profissional@turni.com.br', 'email'],
    'telefone' => ['+5511999998888', 'telefone'],
    'aleatoria' => ['123e4567-e89b-12d3-a456-426614174000', 'aleatoria'],
]);

test('chave Pix inválida é rejeitada', function (string $chave) {
    expect(ChavePixValidator::valida($chave))->toBeFalse();
    expect(ChavePixValidator::tipo($chave))->toBeNull();
})->with([
    'vazia' => [''],
    'texto solto' => ['minha-chave'],
    'email malformado' => ['nao-tem-arroba.com'],
    'cpf com dígito errado' => ['52998224724'],
    'telefone sem +55' => ['11999998888'],
    'uuid incompleto' => ['123e4567-e89b-12d3-a456'],
]);
