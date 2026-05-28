<?php

// Rotas da API (Sanctum SPA + sessão stateful — ADR-007 §b).
// auth.session: grupo com sessão para endpoints que precisam de Auth::login().
// auth.protected: requer sessão ativa + role check + funnel guard.

use App\Http\Controllers\AuthController;
use App\Http\Middleware\FunnelGuard;
use App\Http\Middleware\WebAppOnly;
use Illuminate\Session\Middleware\StartSession;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Route;

// Auth — sem sessão requerida para validação de credencial; com sessão para criar a sessão.
// StartSession é explícito aqui porque o grupo `api` não inclui sessão por padrão.
Route::middleware([StartSession::class])->group(function () {
    Route::post('/login', [AuthController::class, 'login']);
    Route::post('/logout', [AuthController::class, 'logout']);
});

// Rotas protegidas — requerem sessão + WebApp-only + funnel guard
Route::middleware(['auth:web', WebAppOnly::class, FunnelGuard::class, StartSession::class])->group(function () {
    Route::get('/user', function () {
        $user = Auth::user();

        return response()->json([
            'id' => $user->id,
            'name' => $user->name,
            'email' => $user->email,
            'role' => $user->role,
            'status' => $user->status,
            'welcome_visto' => $user->welcome_seen_at !== null,
            'cadastro_completo' => $user->cadastro_completed_at !== null,
        ]);
    });
});
