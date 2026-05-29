<?php

namespace App\Support;

/**
 * Mascaramento de dados pessoais para logs estruturados (ADR-008 §mascaramento).
 * Mantém o domínio (útil para diagnóstico) e oculta a parte local do e-mail.
 */
class Pii
{
    /** "diego.silva@gmail.com" → "d***@gmail.com". */
    public static function maskEmail(?string $email): string
    {
        if (! $email || ! str_contains($email, '@')) {
            return '***';
        }

        [$local, $domain] = explode('@', $email, 2);
        $first = mb_substr($local, 0, 1);

        return ($first !== '' ? $first : '*').'***@'.$domain;
    }
}
