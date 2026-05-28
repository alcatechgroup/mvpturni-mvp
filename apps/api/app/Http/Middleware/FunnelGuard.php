<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Camada backend do funnel guard (CA-10 — dupla camada: Flutter + API).
 *
 * Usuário não-ativo em rota interna da API recebe 423 com o estado do funil.
 * O Flutter faz o roteamento visual; o backend garante que dados não vazam
 * para usuários com cadastro incompleto mesmo que o Flutter seja contornado.
 */
class FunnelGuard
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = Auth::guard('web')->user();

        if (! $user) {
            return response()->json(['message' => 'Não autenticado.'], 401);
        }

        $state = $user->funnelState();

        if ($state !== 'active') {
            return response()->json([
                'message' => 'Acesso restrito.',
                'funnel_state' => $state,
            ], 423);
        }

        return $next($request);
    }
}
