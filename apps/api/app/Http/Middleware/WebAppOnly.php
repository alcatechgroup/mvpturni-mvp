<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Garante que rotas da API são acessíveis apenas por contratante/profissional.
 * Admin não tem fluxo no WebApp — se tentar via cookie, é bloqueado (CA-9).
 */
class WebAppOnly
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = Auth::guard('web')->user();

        if ($user && $user->isAdmin()) {
            return response()->json([
                'message' => 'Admins não acessam o WebApp.',
                'code' => 'admin_must_use_backoffice',
                'backoffice_url' => config('app.backoffice_url', env('BACKOFFICE_URL', '')),
            ], 403);
        }

        return $next($request);
    }
}
