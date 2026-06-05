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
];
