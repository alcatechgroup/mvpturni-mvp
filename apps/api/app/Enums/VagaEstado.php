<?php

namespace App\Enums;

/**
 * STORY-044 / ADR-013 (CA-4, Decisão 2). Estados da Vaga. O tipo é um enum NATIVO do
 * Postgres (`vaga_estado`); este enum PHP espelha os rótulos e carrega as transições
 * válidas — a máquina de estados vive no domínio, não em trigger (ADR-013 Decisão 2).
 * Transições: domain/vaga.md.
 */
enum VagaEstado: string
{
    case Aberta = 'aberta';
    case Fechada = 'fechada';
    case Cancelada = 'cancelada';

    /** Uma transição é válida apenas se mapeada aqui (fail-closed). */
    public function canTransitionTo(self $to): bool
    {
        return match ($this) {
            self::Aberta => in_array($to, [self::Fechada, self::Cancelada], true),
            // fechada e cancelada são terminais (domain/vaga.md: fechada→cancelada proibido).
            self::Fechada, self::Cancelada => false,
        };
    }
}
