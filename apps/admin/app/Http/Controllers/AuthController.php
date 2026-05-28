<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Services\AuditLogService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function __construct(private readonly AuditLogService $audit) {}

    /** GET /login */
    public function showLogin(): \Illuminate\View\View
    {
        return view('auth.login');
    }

    /**
     * POST /login — autenticação do admin com guard web (CA-6, CA-8).
     * Grava admin.login, admin.login_failed, admin.login_attempt_non_admin no audit log (ADR-009).
     */
    public function login(Request $request): RedirectResponse
    {
        $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::where('email', $request->input('email'))->first();

        // Credencial inválida — sem leak de role (CA-8)
        if (! $user || ! Hash::check($request->input('password'), $user->password)) {
            $this->audit->log('admin.login_failed', null, null, null, [
                'email' => $request->input('email'),
            ]);
            throw ValidationException::withMessages([
                'email' => [__('auth.failed')],
            ]);
        }

        // Credencial válida mas não-admin — 403 fail-secure (CA-8)
        if (! $user->isAdmin()) {
            $this->audit->log('admin.login_attempt_non_admin', $user->id, 'User', $user->id, [
                'email' => $user->email,
                'role' => $user->role,
            ]);
            abort(403);
        }

        // Admin autenticado com sucesso
        Auth::login($user, $request->boolean('remember'));
        $request->session()->regenerate();

        $this->audit->log('admin.login', $user->id, null, null, [
            'email' => $user->email,
        ]);

        return redirect()->intended('/');
    }

    /** POST /logout */
    public function logout(Request $request): RedirectResponse
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect('/login');
    }
}
