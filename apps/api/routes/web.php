<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Health-check (ADR-008): liveness sempre 200; readiness verifica Postgres.
// Versão exposta via version.json (IDR-002) e também aqui para conveniência.
Route::get('/health', function () {
    $deep = request()->boolean('deep');
    $status = 'ok';
    $code = 200;

    if ($deep) {
        try {
            DB::select('SELECT 1');
        } catch (\Throwable) {
            $status = 'degraded';
            $code = 503;
        }
    }

    return response()->json([
        'status'    => $status,
        'version'   => env('APP_VERSION', 'unknown'),
        'timestamp' => now()->toIso8601String(),
    ], $code);
});
