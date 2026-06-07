<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Ambiente Turni (STORY-075 / PDR-017)
    |--------------------------------------------------------------------------
    |
    | Identifica o ambiente de NEGÓCIO (local / homolog / production) — não o
    | de runtime do Laravel: em homolog os serviços rodam deliberadamente com
    | APP_ENV=production (otimizações de framework), então app()->environment()
    | não distingue homolog de produção. TURNI_ENV é definida no Terraform de
    | homolog (infra/envs/homolog) e ausente em prod/dev → default `local`,
    | fail-safe: o banner "Ambiente de teste" só renderiza com o valor exato
    | `homolog`.
    |
    */

    'env' => env('TURNI_ENV', 'local'),

];
