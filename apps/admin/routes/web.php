<?php

use App\Http\Controllers\AuthController;
use App\Http\Middleware\AdminOnly;
use App\Livewire\FilaAprovacao;
use App\Livewire\TemplateDetalhe;
use App\Livewire\TemplateEditor;
use App\Livewire\TemplatesCatalogo;
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

// Recuperação de senha — stub (CA-5: o link existe e leva a um destino funcional;
// envio real de e-mail fica para STORY-021). Evita o 404 do link no /login.
Route::get('/esqueci-minha-senha', fn () => view('auth.forgot-password'))
    ->name('password.request');

// Rotas protegidas — requerem admin
Route::middleware([AdminOnly::class])->group(function () {
    Route::get('/', function () {
        return view('dashboard');
    })->name('dashboard');

    // STORY-019 — Fila de aprovação (componente Livewire full-page).
    Route::get('/aprovacoes', FilaAprovacao::class)->name('aprovacoes');

    // STORY-020 — Editor de templates contratuais (catálogo · detalhe · editor de nova versão).
    Route::get('/templates', TemplatesCatalogo::class)->name('templates.catalogo');
    Route::get('/templates/{slug}/nova-versao', TemplateEditor::class)->name('templates.editor');
    Route::get('/templates/{slug}', TemplateDetalhe::class)->name('templates.detalhe');
});
