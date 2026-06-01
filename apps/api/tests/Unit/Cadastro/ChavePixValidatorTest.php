<?php

use App\Domain\Cadastro\ChavePixValidator;

test('detecta tipo de chave Pix válida', function (string $chave, string $tipo) {
    expect(ChavePixValidator::detectarTipo($chave))->toBe($tipo);
    expect(ChavePixValidator::valida($chave))->toBeTrue();
})->with([
    'email' => ['maria.silva@exemplo.com', 'email'],
    'cpf' => ['11144477735', 'cpf'],
    'cnpj' => ['11222333000181', 'cnpj'],
    'telefone E.164' => ['+5511999998888', 'telefone'],
    'aleatoria (UUID)' => ['123e4567-e89b-12d3-a456-426614174000', 'aleatoria'],
]);

test('rejeita chave Pix inválida', function (string $chave) {
    expect(ChavePixValidator::detectarTipo($chave))->toBeNull();
    expect(ChavePixValidator::valida($chave))->toBeFalse();
})->with([
    'vazia' => '   ',
    'email malformado' => 'maria@@exemplo',
    'cpf inválido' => '11144477700',
    'telefone sem +' => '11999998888',
    'texto livre' => 'minha chave pix',
    'uuid incompleto' => '123e4567-e89b-12d3-a456',
]);
