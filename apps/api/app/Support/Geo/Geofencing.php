<?php

namespace App\Support\Geo;

/**
 * STORY-057 / ADR-017 (decisão b). Núcleo do geofencing de check-in (PDR-008, alerta-e-registra):
 * dada a posição do profissional (capturada pelo navegador) e a do estabelecimento, decide a flag
 * `geofencing_ok` e a distância em metros. **Reusa `Haversine`** (STORY-049) — o mesmo cálculo do
 * feed; aqui só convertemos km → metros e aplicamos o raio.
 *
 * É uma função pura (sem relógio, sem rede, sem banco) para ser testável isoladamente e nunca
 * bloquear: PDR-008 manda alertar-e-registrar, então qualquer falta de coordenada vira
 * `ok:false`, `distancia_metros:null` + razão — nunca uma exceção. O `capturado_em` (timestamp) e
 * a persistência do snapshot são responsabilidade de quem chama (controller/STORY-061).
 */
final class Geofencing
{
    /** Raio do estabelecimento em metros (domain/turno.md — 100m). */
    public const RAIO_PADRAO_METROS = 100;

    /**
     * Avalia a posição do profissional contra a do estabelecimento.
     *
     * @param  ?string  $razaoSemCoordenada  razão informada pelo cliente quando ele não obteve a
     *                                       posição (`permissao_negada`, `timeout`, `indisponivel`);
     *                                       usada só quando falta coordenada do profissional.
     * @return array{ok:bool,distancia_metros:?float,razao:?string}
     */
    public static function avaliar(
        ?float $latPro,
        ?float $lngPro,
        ?float $latEstab,
        ?float $lngEstab,
        int $raioMetros = self::RAIO_PADRAO_METROS,
        ?string $razaoSemCoordenada = null,
    ): array {
        $km = Haversine::km($latPro, $lngPro, $latEstab, $lngEstab);

        // Sem coordenada de algum lado (permissão negada, GPS off, estabelecimento sem geo): não
        // bloqueia (PDR-008) — registra ok:false sem distância, com a razão para a trilha de auditoria.
        if ($km === null) {
            return [
                'ok' => false,
                'distancia_metros' => null,
                'razao' => $razaoSemCoordenada ?? 'sem_coordenada',
            ];
        }

        $metros = round($km * 1000, 1);

        return [
            'ok' => $metros <= $raioMetros,
            'distancia_metros' => $metros,
            // Dentro do raio não há razão; fora do raio a razão explica o alerta ao contratante.
            'razao' => $metros <= $raioMetros ? null : 'fora_do_raio',
        ];
    }
}
