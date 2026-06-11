<?php

namespace App\Services\Disputas;

/**
 * STORY-096 (CA-3/CA-4) — desfecho da chamada admin→api do comando "pagar integral".
 * O Livewire mapeia cada caso para o feedback ao admin (toast/erro).
 */
enum ResultadoResolucao
{
    /** 200 — turno transitado para `finalizado`; captura+Pix disparadas na api. */
    case Ok;

    /** 422 `estado_invalido` — turno já saiu de `em_disputa` (resolvido por outro admin). */
    case Concorrente;

    /** Qualquer outra falha (401/403/422 não-concorrente/5xx/rede) — sem efeito duplicado. */
    case Erro;
}
