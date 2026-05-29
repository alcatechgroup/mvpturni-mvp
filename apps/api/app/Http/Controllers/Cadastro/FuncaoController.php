<?php

namespace App\Http\Controllers\Cadastro;

use App\Http\Controllers\Controller;
use App\Models\Funcao;
use Illuminate\Http\JsonResponse;

/**
 * STORY-017 — Lista pública de funções ativas para o select do pré-cadastro.
 * Coerente com IDR-008 (funções são dado, não enum hard-coded).
 */
class FuncaoController extends Controller
{
    public function index(): JsonResponse
    {
        $funcoes = Funcao::query()
            ->where('ativo', true)
            ->orderBy('nome')
            ->get(['id', 'slug', 'nome']);

        return response()->json(['data' => $funcoes]);
    }
}
