<?php

namespace App\Domain\Cadastro;

/**
 * STORY-023 CA-4 — Validação básica de formato da chave Pix. Detecta e valida os
 * cinco tipos aceitos pelo arranjo Pix: CPF, CNPJ, e-mail, telefone (E.164) e
 * chave aleatória (EVP/UUID). Sem chamada externa — só formato (função pura).
 */
final class ChavePixValidator
{
    /** Detecta o tipo da chave Pix, ou null se inválida em todos os formatos. */
    public static function detectarTipo(string $chave): ?string
    {
        $v = trim($chave);

        if ($v === '') {
            return null;
        }

        if (str_contains($v, '@')) {
            return filter_var($v, FILTER_VALIDATE_EMAIL) ? 'email' : null;
        }

        // Chave aleatória (EVP): UUID v4 — 8-4-4-4-12 hexadecimal.
        if (preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $v)) {
            return 'aleatoria';
        }

        // Telefone E.164: começa com + e tem código do país (Pix exige formato internacional).
        if (str_starts_with($v, '+')) {
            return preg_match('/^\+[1-9]\d{9,14}$/', $v) ? 'telefone' : null;
        }

        $digitos = preg_replace('/\D/', '', $v) ?? '';

        if (strlen($digitos) === 11 && DocumentoValidator::cpfValido($digitos)) {
            return 'cpf';
        }

        if (strlen($digitos) === 14 && DocumentoValidator::cnpjValido($digitos)) {
            return 'cnpj';
        }

        return null;
    }

    public static function valida(string $chave): bool
    {
        return self::detectarTipo($chave) !== null;
    }
}
