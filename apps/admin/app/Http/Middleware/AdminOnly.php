<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Garante que apenas admins acessam o Backoffice (CA-8 — fail-secure).
 * Não-autenticados → redireciona para /login.
 * Autenticados não-admin → 403.
 */
class AdminOnly
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->user()) {
            return redirect('/login');
        }

        if (! $request->user()->isAdmin()) {
            abort(403);
        }

        return $next($request);
    }
}
