<?php

namespace App\Http\Controllers\Usuario;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

/**
 * STORY-022 — Tela de welcome pós-aprovação.
 *
 * Marca welcome_seen_at do usuário liberado (primeira mudança de estado autodirigida).
 * Fica FORA do FunnelGuard de propósito: o usuário que precisa marcar welcome está
 * justamente em `await_welcome` — o guard o bloquearia com 423. Protegido por sessão
 * (auth:web) + WebAppOnly (admin não acessa o WebApp).
 */
class WelcomeController extends Controller
{
    /**
     * POST /api/usuarios/me/welcome-visto (CA-4, CA-8, CA-12).
     *
     * Idempotente: marca welcome_seen_at = now() apenas se ainda null; se já marcado,
     * é no-op silencioso (não erra, não regrava o timestamp). Sempre retorna o estado.
     */
    public function markSeen(): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();

        // CA-8 — idempotência: só grava na primeira vez. Re-chamada não sobrescreve.
        if ($user->welcome_seen_at === null) {
            $user->forceFill(['welcome_seen_at' => now()])->save();

            // CA-12 — log estruturado (ADR-008), sem PII clara (sem nome/e-mail no contexto).
            Log::info('user.welcome_seen', [
                'event' => 'user.welcome_seen',
                'user_id' => $user->id,
                'role' => $user->role,
                'timestamp' => $user->welcome_seen_at->toIso8601String(),
            ]);
        }

        return response()->json([
            'name' => $user->name,
            'role' => $user->role,
            'status' => $user->status,
            'welcome_visto' => $user->welcome_seen_at !== null,
            'cadastro_completo' => $user->cadastro_completed_at !== null,
        ]);
    }
}
