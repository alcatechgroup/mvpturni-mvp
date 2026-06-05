<?php

namespace App\Domain\Turno;

/**
 * STORY-058 (CA-3/CA-4) — desfecho do gate de habitualidade no ACEITE (PDR-002).
 *
 * `Liberado` — par profissional × estabelecimento abaixo do limite semanal (< 2 turnos).
 * `BloqueadoPf` — profissional PF na 3ª alocação da semana: bloqueio duro, sem override.
 * `RequerOverride` — MEI/PJ na 3ª: o contratante pode prosseguir com aceite explícito de
 *                    risco ("Assumo o risco e aceito"), carimbado no aceite eletrônico.
 */
enum HabitualidadeAceite
{
    case Liberado;
    case BloqueadoPf;
    case RequerOverride;
}
