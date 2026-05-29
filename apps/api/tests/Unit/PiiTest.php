<?php

// STORY-017 — CA-12 — Mascaramento de e-mail para log estruturado (ADR-008).

use App\Support\Pii;

test('mascara e-mail mantendo a primeira letra e o domínio', function () {
    expect(Pii::maskEmail('diego.silva@gmail.com'))->toBe('d***@gmail.com');
    expect(Pii::maskEmail('a@turni.com.br'))->toBe('a***@turni.com.br');
});

test('mascara e-mail com parte local de um caractere', function () {
    expect(Pii::maskEmail('x@dominio.com'))->toBe('x***@dominio.com');
});

test('retorna placeholder para entrada vazia ou inválida', function () {
    expect(Pii::maskEmail(null))->toBe('***');
    expect(Pii::maskEmail(''))->toBe('***');
    expect(Pii::maskEmail('sem-arroba'))->toBe('***');
});
