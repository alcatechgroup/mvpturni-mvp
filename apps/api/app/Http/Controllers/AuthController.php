<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;

class AuthController extends Controller
{
    /**
     * POST /api/login — autenticação Sanctum SPA (CA-3, CA-7).
     *
     * Throttle: 5 tentativas/min por email+IP (ADR-007 §f).
     * Nunca revela se o e-mail existe em erros de credencial (CA-3 — sem leak).
     * Admin autenticado com sucesso é rejeitado com código específico (CA-7).
     */
    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
        ]);

        $throttleKey = strtolower($request->input('email')).'|'.$request->ip();
        $maxAttempts = 5;

        if (RateLimiter::tooManyAttempts($throttleKey, $maxAttempts)) {
            $seconds = RateLimiter::availableIn($throttleKey);

            return response()->json([
                'message' => 'Muitas tentativas. Aguarde antes de tentar novamente.',
                'retry_after' => $seconds,
            ], 429);
        }

        $user = User::where('email', $request->input('email'))->first();

        if (! $user || ! Hash::check($request->input('password'), $user->password)) {
            RateLimiter::hit($throttleKey, 60);

            return response()->json([
                'message' => 'Credenciais inválidas.',
                'code' => 'invalid_credentials',
            ], 401);
        }

        // Credencial válida — admin não pode usar o WebApp (CA-7).
        if ($user->isAdmin()) {
            RateLimiter::clear($throttleKey);

            return response()->json([
                'message' => 'Este usuário acessa o Backoffice.',
                'code' => 'admin_must_use_backoffice',
                'backoffice_url' => config('app.backoffice_url', env('BACKOFFICE_URL', '')),
            ], 403);
        }

        RateLimiter::clear($throttleKey);

        Auth::login($user);
        $request->session()->regenerate();

        return response()->json([
            'role' => $user->role,
            'status' => $user->status,
            'welcome_visto' => $user->welcome_seen_at !== null,
            'cadastro_completo' => $user->cadastro_completed_at !== null,
        ]);
    }

    /**
     * POST /api/logout — invalida sessão no servidor (CA-4).
     * Logout do admin NÃO grava no audit log aqui (a API não é usada pelo admin).
     */
    public function logout(Request $request): JsonResponse
    {
        Auth::guard('web')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return response()->json(['message' => 'Sessão encerrada.']);
    }
}
