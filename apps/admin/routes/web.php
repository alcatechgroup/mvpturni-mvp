<?php

use App\Http\Controllers\AuthController;
use App\Http\Middleware\AdminOnly;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

// Health-check (ADR-008)
Route::get('/health', function () {
    $deep = request()->boolean('deep');
    $status = 'ok';
    $code = 200;

    if ($deep) {
        try {
            DB::select('SELECT 1');
        } catch (Throwable) {
            $status = 'degraded';
            $code = 503;
        }
    }

    return response()->json([
        'status' => $status,
        'version' => env('APP_VERSION', 'unknown'),
        'timestamp' => now()->toIso8601String(),
        'service' => 'backoffice',
    ], $code);
});

// Auth — públicas
Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
Route::post('/login', [AuthController::class, 'login']);
Route::post('/logout', [AuthController::class, 'logout'])->name('logout');

// Rotas protegidas — requerem admin
Route::middleware([AdminOnly::class])->group(function () {
    Route::get('/', function () {
        return view('dashboard');
    })->name('dashboard');
});
