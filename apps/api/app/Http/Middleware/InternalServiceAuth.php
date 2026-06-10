<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * STORY-093 / ADR-020 (Decisão 3A) · IDR-032 — autenticação do canal service-to-service admin→api.
 *
 * A resolução de disputa "pagar integral" MOVE DINHEIRO e a captura só pode ser disparada pela api
 * (evento in-process `TurnoFinalizado` que o `apps/admin`, processo separado, não consegue emitir).
 * As rotas do WebApp usam `auth:web` (sessão por cookie do Flutter) — o admin não tem essa sessão.
 * Este guard protege as rotas `/api/internal/*`: exige o segredo compartilhado nos 2 `.env`
 * (`INTERNAL_SERVICE_TOKEN` — mesmo racional do `pix_falha_chave_key`/IDR-028), comparado em tempo
 * constante. Fail-secure: segredo ausente na config OU header divergente → 401. A IDENTIDADE do
 * admin (`admin_id`) é asserida pelo app admin confiável e re-verificada (`isAdmin()`) no controller.
 */
class InternalServiceAuth
{
    public function handle(Request $request, Closure $next): Response
    {
        $esperado = (string) config('services.internal.token');
        $fornecido = (string) $request->header('X-Internal-Token', '');

        if ($esperado === '' || ! hash_equals($esperado, $fornecido)) {
            abort(401);
        }

        return $next($request);
    }
}
