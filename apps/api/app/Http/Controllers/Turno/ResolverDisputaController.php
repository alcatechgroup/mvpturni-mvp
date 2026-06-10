<?php

namespace App\Http\Controllers\Turno;

use App\Http\Controllers\Controller;
use App\Models\Turno;
use App\Models\User;
use App\Services\NotaAdminObrigatoriaException;
use App\Services\PinCheckinEstadoInvalidoException;
use App\Services\ResolverDisputaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-093 / ADR-020 (Decisão 3A) — POST /api/internal/turnos/{turno}/resolver-disputa.
 *
 * Endpoint INTERNO (service-to-service) que o backoffice (STORY-096) invoca quando um admin
 * decide "pagar integral". A autenticidade do CANAL vem do InternalServiceAuth (segredo
 * compartilhado); a IDENTIDADE do admin chega no corpo (`admin_id`, asserida pelo app admin
 * confiável) e é re-verificada aqui (fail-secure): se o id não existe ou não é admin → 403
 * (CA-5). `nota_admin` é OBRIGATÓRIA (ADR-020 Decisão 3; o conflito com a CA-3 "opcional" foi
 * resolvido a favor do ADR). A captura+Pix, a transição e a trilha são do ResolverDisputaService.
 */
class ResolverDisputaController extends Controller
{
    public function __construct(private readonly ResolverDisputaService $service) {}

    public function resolver(Request $request, Turno $turno): JsonResponse
    {
        $dados = $request->validate([
            'admin_id' => ['required', 'string'],
            'nota_admin' => ['required', 'string', 'max:2000'],
        ]);

        $admin = User::find($dados['admin_id']);
        abort_unless($admin !== null && $admin->isAdmin(), 403); // RBAC fail-secure (CA-5)

        try {
            return response()->json($this->service->resolverPagaIntegral($turno, $admin, $dados['nota_admin']));
        } catch (NotaAdminObrigatoriaException) {
            return response()->json(['motivo' => 'nota_admin_obrigatoria'], 422);
        } catch (PinCheckinEstadoInvalidoException $e) {
            return response()->json(['motivo' => 'estado_invalido', 'estado' => $e->estado], 422);
        }
    }
}
