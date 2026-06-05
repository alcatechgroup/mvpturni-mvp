<?php

namespace App\Domain\Turno;

use RuntimeException;

/**
 * STORY-061 (CA-3) — geração do PIN de check-in: 4 dígitos uniformes (`random_int`) com
 * retry anti-trivial. O CA marcava o anti-trivial como opcional; implementado porque o
 * custo é uma rejeição rara (24 valores em 10.000 ≈ 0,24%) e o ganho é um PIN menos
 * chutável pelo contratante errado. Trivial = 4 dígitos repetidos ("0000".."9999") ou
 * sequência de passo 1 ascendente/descendente ("0123".."6789", "9876".."3210" — sem wrap).
 *
 * Função pura (fonte de aleatoriedade injetável para teste). O HASH do PIN (bcrypt via
 * `Hash::make`, mesmo do EPIC-001) e a persistência são de quem chama — o plaintext só
 * existe na resposta da geração (CA-4) e nunca em log.
 */
final class PinCheckin
{
    /** Guarda contra fonte degenerada (só triviais) — nunca loop infinito. */
    private const MAX_TENTATIVAS = 100;

    /** @param ?callable(): int $fonte sorteia em [0, 9999]; default `random_int` (CSPRNG). */
    public static function gerar(?callable $fonte = null): string
    {
        $fonte ??= fn (): int => random_int(0, 9999);

        for ($i = 0; $i < self::MAX_TENTATIVAS; $i++) {
            $pin = str_pad((string) $fonte(), 4, '0', STR_PAD_LEFT);

            if (! self::ehTrivial($pin)) {
                return $pin;
            }
        }

        throw new RuntimeException('PinCheckin: fonte de aleatoriedade só devolveu PINs triviais.');
    }

    public static function ehTrivial(string $pin): bool
    {
        $d = array_map(intval(...), str_split($pin));

        $repetido = count(array_unique($d)) === 1;
        $ascendente = $d[1] - $d[0] === 1 && $d[2] - $d[1] === 1 && $d[3] - $d[2] === 1;
        $descendente = $d[0] - $d[1] === 1 && $d[1] - $d[2] === 1 && $d[2] - $d[3] === 1;

        return $repetido || $ascendente || $descendente;
    }
}
