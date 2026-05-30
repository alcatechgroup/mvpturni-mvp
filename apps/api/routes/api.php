<?php

// Rotas da API (Sanctum SPA + sessão stateful — ADR-007 §b).
// auth.session: grupo com sessão para endpoints que precisam de Auth::login().
// auth.protected: requer sessão ativa + role check + funnel guard.

use App\Http\Controllers\AuthController;
use App\Http\Controllers\Cadastro\ContratanteCadastroController;
use App\Http\Controllers\Cadastro\FuncaoController;
use App\Http\Controllers\Cadastro\ProfissionalCadastroController;
use App\Http\Controllers\Usuario\WelcomeController;
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

    // Pré-cadastro público de profissional (STORY-017). Pública (sem auth), mas dentro
    // do escopo stateful/CSRF do Sanctum — segue o padrão de submit da API (ADR-007).
    Route::post('/cadastro/profissional', [ProfissionalCadastroController::class, 'store']);

    // Pré-cadastro público de contratante (STORY-018). Mesmo padrão stateful/CSRF.
    Route::post('/cadastro/contratante', [ContratanteCadastroController::class, 'store']);
});

// Lista pública de funções para o select do pré-cadastro (STORY-017). GET sem estado.
Route::get('/funcoes', [FuncaoController::class, 'index']);

// Welcome pós-aprovação (STORY-022). Protegida por sessão + WebApp-only, mas FORA do
// FunnelGuard: o usuário que marca welcome está em `await_welcome` (o guard o bloquearia
// com 423). Idempotente — ver WelcomeController.
Route::middleware(['auth:web', WebAppOnly::class, StartSession::class])->group(function () {
    Route::post('/usuarios/me/welcome-visto', [WelcomeController::class, 'markSeen']);
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
