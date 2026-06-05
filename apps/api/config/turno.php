<?php

// STORY-061 (CA-1) — janela de geração do PIN de check-in, relativa a `data_inicio`:
// [data_inicio − antes, data_inicio + depois], bordas inclusivas. Defaults explícitos da
// estória (30 min antes / 2h depois); configuráveis por env sem deploy de código.
return [
    'checkin_janela_antes_min' => (int) env('TURNI_CHECKIN_JANELA_ANTES_MIN', 30),
    'checkin_janela_depois_min' => (int) env('TURNI_CHECKIN_JANELA_DEPOIS_MIN', 120),
];
