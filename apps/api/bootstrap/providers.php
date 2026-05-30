<?php

use App\Providers\AppServiceProvider;
use App\Providers\FortifyServiceProvider;

return [
    AppServiceProvider::class,
    // STORY-021: o FortifyServiceProvider existia desde a STORY-016 mas nunca foi
    // registrado — sem ele as customizações do Fortify (actions, rate limiters e as
    // respostas de reset de senha) não eram aplicadas. Registrado aqui.
    FortifyServiceProvider::class,
];
