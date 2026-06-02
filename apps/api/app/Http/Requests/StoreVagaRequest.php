<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * STORY-046 — validação de POST /api/vagas (CA-2/CA-3). Espelha no servidor as regras
 * do client (domain/vaga.md): 6 campos materiais, função na lista canônica ativa,
 * data_fim > data_inicio, valor > 0, posições ≥ 1. RBAC (CA-1) no authorize():
 * só contratante (o FunnelGuard já garante status=ativo na rota).
 */
class StoreVagaRequest extends FormRequest
{
    public function authorize(): bool
    {
        $user = $this->user();

        return $user !== null && $user->isContratante();
    }

    /** @return array<string,mixed> */
    public function rules(): array
    {
        return [
            'funcao_id' => [
                'required', 'integer',
                Rule::exists('funcoes', 'id')->where('ativo', true),
            ],
            'data_inicio' => ['required', 'date'],
            'data_fim' => ['required', 'date', 'after:data_inicio'],
            'valor' => ['required', 'numeric', 'min:0.01'],
            'posicoes' => ['required', 'integer', 'min:1'],
            'observacoes' => ['nullable', 'string', 'max:1000'],
        ];
    }

    /** @return array<string,string> */
    public function messages(): array
    {
        return [
            'funcao_id.required' => 'Escolha a função do turno.',
            'funcao_id.exists' => 'Escolha uma função válida da lista.',
            'data_inicio.required' => 'Informe quando o turno começa.',
            'data_fim.required' => 'Informe quando o turno termina.',
            'data_fim.after' => 'O fim precisa ser depois do início.',
            'valor.required' => 'Informe o valor por turno.',
            'valor.min' => 'Informe o valor por turno.',
            'posicoes.required' => 'Pelo menos 1 posição.',
            'posicoes.min' => 'Pelo menos 1 posição.',
        ];
    }
}
