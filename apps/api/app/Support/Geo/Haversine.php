<?php

namespace App\Support\Geo;

/**
 * STORY-049 — distância Haversine reutilizável entre o feed (FeedQuery) e o detalhe da vaga
 * (VagaDetalheQuery). Extraída de FeedQuery (STORY-048) para evitar duplicar a fórmula: o
 * detalhe precisa exatamente da mesma distância que o feed usou para pontuar o match.
 *
 * Retorna null quando falta geo de qualquer lado — o componente de distância então zera no
 * match (ADR-014) e a UI omite a distância (SCREEN-049 §4.8).
 */
final class Haversine
{
    /** Raio médio da Terra em km. */
    private const RAIO_TERRA_KM = 6371.0;

    public static function km(?float $lat1, ?float $lng1, ?float $lat2, ?float $lng2): ?float
    {
        if ($lat1 === null || $lng1 === null || $lat2 === null || $lng2 === null) {
            return null;
        }

        $rLat1 = deg2rad($lat1);
        $rLat2 = deg2rad($lat2);
        $dLat = deg2rad($lat1 - $lat2);
        $dLng = deg2rad($lng1 - $lng2);

        $a = sin($dLat / 2) ** 2 + cos($rLat1) * cos($rLat2) * sin($dLng / 2) ** 2;

        return self::RAIO_TERRA_KM * 2 * asin(min(1.0, sqrt($a)));
    }
}
