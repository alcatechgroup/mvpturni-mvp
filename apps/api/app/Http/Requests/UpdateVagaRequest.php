<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * STORY-052 — validação de PATCH /api/vagas/{vaga} (CA-1). O WebApp envia o formulário inteiro
 * (mesmo de publicar — SCREEN-052 reusa SCREEN-046), então exigimos os 6 campos materiais como
 * no StoreVagaRequest; o detector de edição material (EdicaoMaterial) compara contra o estado
 * atual depois da validação. RBAC de papel no authorize(); a posse da vaga (ser o dono) é
 * verificada no controller (403), como no DELETE de STORY-047.
 */
class UpdateVagaRequest extends FormRequest
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
                'bail', 'required', 'uuid',
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
