<?php

// STORY-061 (CA-1) — janela de geração do PIN de check-in, relativa a `data_inicio`:
// [data_inicio − antes, data_inicio + depois], bordas inclusivas. Defaults explícitos da
// estória (30 min antes / 2h depois); configuráveis por env sem deploy de código.
return [
    'checkin_janela_antes_min' => (int) env('TURNI_CHECKIN_JANELA_ANTES_MIN', 30),
    'checkin_janela_depois_min' => (int) env('TURNI_CHECKIN_JANELA_DEPOIS_MIN', 120),

    // STORY-062 (CA-2) — rate limit da validação do PIN: requests/60s por TURNO
    // (proteção de borda contra força bruta; o limite de domínio — 3 erros expiram o
    // PIN — é fixo no ValidarCheckinService).
    'checkin_validacao_max_por_minuto' => (int) env('TURNI_CHECKIN_VALIDACAO_MAX_POR_MINUTO', 5),

    // STORY-064 (CA-4) — rate limit da validação do PIN de check-out: espelho do de
    // check-in (mesma proteção de borda contra força bruta, janela própria por turno;
    // o limite de domínio — 3 erros expiram o PIN — é fixo no ValidarCheckoutService).
    'checkout_validacao_max_por_minuto' => (int) env('TURNI_CHECKOUT_VALIDACAO_MAX_POR_MINUTO', 5),

    // STORY-063 (CA-1) — janela de reconciliação do cronômetro bilateral (ADR-017): o
    // cliente tica LOCALMENTE a cada 1s e faz polling nesta janela só para corrigir o
    // offset de relógio e detectar a saída de `ativo`. Configurável por env sem deploy
    // (ajuste de carga: aumentar a janela reduz requests por turno ativo).
    'cronometro_polling_segundos' => (int) env('TURNI_CRONOMETRO_POLLING_SEGUNDOS', 5),
];
