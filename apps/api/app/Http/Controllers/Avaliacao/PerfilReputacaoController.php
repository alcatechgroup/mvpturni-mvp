<?php

namespace App\Http\Controllers\Avaliacao;

use App\Domain\Avaliacao\PerfilReputacaoQuery;
use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-085 / ADR-019 + DDR-004 (CA-6) — GET /api/perfil/{user}: reputação consultável do
 * perfil (score/nível/XP/depoimentos). Reputação é dado público-de-produto: qualquer usuário
 * ativo consulta (o grupo de rotas já garante sessão + funil). O XP só é devolvido ao próprio
 * dono (visibilidade — niveis-e-score.md); a assimetria de autor dos depoimentos (LGPD) é
 * resolvida na PerfilReputacaoQuery.
 */
class PerfilReputacaoController extends Controller
{
    public function __construct(private readonly PerfilReputacaoQuery $query) {}

    public function show(Request $request, User $user): JsonResponse
    {
        $ehDono = $request->user()->id === $user->id;

        return response()->json($this->query->para($user, $ehDono));
    }
}
