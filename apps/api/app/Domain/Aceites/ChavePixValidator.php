<?php

namespace App\Domain\Aceites;

/**
 * STORY-023 / CA-4 — Validação básica de chave Pix (tipo + formato).
 *
 * Aceita os 5 tipos do arranjo Pix: CPF, CNPJ, e-mail, telefone (E.164 BR) e chave aleatória
 * (EVP/UUID). Validação de formato apenas — não há consulta ao DICT no MVP.
 */
class ChavePixValidator
{
    public static function valida(string $chave): bool
    {
        return self::tipo($chave) !== null;
    }

    /** Retorna o tipo detectado (`cpf|cnpj|email|telefone|aleatoria`) ou null se inválida. */
    public static function tipo(string $chave): ?string
    {
        $valor = trim($chave);

        if ($valor === '') {
            return null;
        }

        // Chave aleatória (EVP): UUID v4 textual de 36 caracteres.
        if (preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $valor)) {
            return 'aleatoria';
        }

        if (str_contains($valor, '@')) {
            return filter_var($valor, FILTER_VALIDATE_EMAIL) ? 'email' : null;
        }

        // Telefone no formato E.164 do Brasil: +55 + DDD(2) + número(8-9).
        if (preg_match('/^\+55\d{10,11}$/', $valor)) {
            return 'telefone';
        }

        $digitos = preg_replace('/\D/', '', $valor) ?? '';

        if (strlen($digitos) === 11 && DocumentoValidator::cpfValido($digitos)) {
            return 'cpf';
        }

        if (strlen($digitos) === 14 && DocumentoValidator::cnpjValido($digitos)) {
            return 'cnpj';
        }

        return null;
    }
}
