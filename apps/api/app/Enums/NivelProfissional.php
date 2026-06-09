<?php

namespace App\Enums;

/**
 * STORY-085 / ADR-019 Decisão 4. Dono dos limiares da trilha de níveis (niveis-e-score.md) e
 * da função `nivelPara(xp)`. Os valores batem com os rótulos persistidos em
 * `profissional_profiles.nivel` (string). `ordem()` sustenta o high-water-mark do motor
 * (nível sobe, nunca rebaixa). Centraliza o que o Match resolvia por string ad-hoc — o Match
 * pode adotá-lo depois (não obrigatório).
 */
enum NivelProfissional: string
{
    case Iniciante = 'Iniciante';   // 0 – 499
    case Confiavel = 'Confiavel';   // 500 – 999
    case Destaque = 'Destaque';     // 1000 – 2999
    case Elite = 'Elite';           // 3000+

    /** Nível correspondente a um XP — limiares de niveis-e-score.md. XP negativo → Iniciante. */
    public static function nivelPara(int $xp): self
    {
        return match (true) {
            $xp >= 3000 => self::Elite,
            $xp >= 1000 => self::Destaque,
            $xp >= 500 => self::Confiavel,
            default => self::Iniciante,
        };
    }

    /** Posição na trilha (crescente) — usada pelo motor para o `max` do high-water-mark. */
    public function ordem(): int
    {
        return match ($this) {
            self::Iniciante => 0,
            self::Confiavel => 1,
            self::Destaque => 2,
            self::Elite => 3,
        };
    }

    /** O maior entre dois níveis (high-water-mark — o nível nunca rebaixa). */
    public function maiorEntre(self $outro): self
    {
        return $this->ordem() >= $outro->ordem() ? $this : $outro;
    }

    /**
     * XP que falta para o próximo limiar acima do XP atual (barra de progresso do perfil —
     * niveis-e-score.md). Elite (>= 3000) não tem próximo → null. XP negativo conta a partir
     * do piso de Confiável (500 − xp).
     */
    public static function xpAteProximoNivel(int $xp): ?int
    {
        foreach ([500, 1000, 3000] as $limiar) {
            if ($xp < $limiar) {
                return $limiar - $xp;
            }
        }

        return null; // Elite — não há próximo nível no MVP
    }
}
