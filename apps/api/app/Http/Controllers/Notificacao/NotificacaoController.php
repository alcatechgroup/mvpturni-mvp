<?php

namespace App\Http\Controllers\Notificacao;

use App\Http\Controllers\Controller;
use App\Models\Notificacao;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-053 (CA-7) — caixa de notificações in-app do usuário autenticado (profissional OU
 * contratante; ambos recebem). Só o **próprio** destinatário lê/marca as suas: o RBAC é
 * `destinatario_id === user->id` (404 para terceiros — não vaza existência).
 *
 *  - GET  /api/notificacoes[?lidas=false]  → últimas 50 (todas) ou só não-lidas + contagem p/ badge.
 *  - POST /api/notificacoes/{notificacao}/marcar-lida
 *  - POST /api/notificacoes/marcar-todas-lidas
 */
class NotificacaoController extends Controller
{
    private const LIMITE = 50;

    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $query = Notificacao::query()->doDestinatario($userId);

        // ?lidas=false → só as não-lidas (badge/caixa filtrada); ausente → últimas 50 (lidas + não).
        if ($request->query('lidas') === 'false') {
            $query->naoLidas();
        }

        $notificacoes = $query->limit(self::LIMITE)->get();

        return response()->json([
            'notificacoes' => $notificacoes->map(fn (Notificacao $n) => $this->serializar($n))->all(),
            // Contagem TOTAL de não-lidas (não limitada a 50) — alimenta o badge do sino (CA-8).
            'nao_lidas' => Notificacao::query()->doDestinatario($userId)->naoLidas()->count(),
        ]);
    }

    public function marcarLida(Request $request, Notificacao $notificacao): JsonResponse
    {
        // 404 (não 403) para quem não é o dono: não revela que a notificação existe.
        abort_unless($notificacao->destinatario_id === $request->user()->id, 404);

        if ($notificacao->lida_em === null) {
            $notificacao->lida_em = now();
            $notificacao->save();
        }

        return response()->json(['ok' => true, 'lida_em' => $notificacao->lida_em?->toIso8601String()]);
    }

    public function marcarTodasLidas(Request $request): JsonResponse
    {
        $marcadas = Notificacao::query()
            ->doDestinatario($request->user()->id)
            ->naoLidas()
            ->update(['lida_em' => now()]);

        return response()->json(['ok' => true, 'marcadas' => $marcadas]);
    }

    /** @return array<string,mixed> */
    private function serializar(Notificacao $n): array
    {
        return [
            'id' => $n->id,
            'tipo' => $n->tipo->value,
            'vaga_id' => $n->vaga_id,
            'candidatura_id' => $n->candidatura_id,
            'payload' => $n->payload,
            'lida_em' => $n->lida_em?->toIso8601String(),
            'criada_em' => $n->criada_em?->toIso8601String(),
        ];
    }
}
