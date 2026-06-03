<?php

namespace App\Support;

use Carbon\CarbonInterface;

/**
 * Formatação de data/hora local pt-BR, 24h (DDR-002 / IDR-026 — "sempre local na UI/e-mail, UTC
 * no banco"). O banco guarda timestamptz em UTC; aqui convertemos para America/Sao_Paulo e
 * formatamos no padrão do produto. Nunca AM/PM.
 */
final class DataHora
{
    public const TZ = 'America/Sao_Paulo';

    /** "03/06/2026 18:00" — usada em e-mail (data completa). */
    public static function completa(?CarbonInterface $dt): ?string
    {
        return $dt?->copy()->setTimezone(self::TZ)->format('d/m/Y H:i');
    }

    /** "12/06 · 18:00" — usada no resumo curto in-app/e-mail. */
    public static function curta(?CarbonInterface $dt): ?string
    {
        return $dt?->copy()->setTimezone(self::TZ)->format('d/m · H:i');
    }
}
