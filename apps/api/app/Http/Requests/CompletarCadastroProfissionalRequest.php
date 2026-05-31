<?php

namespace App\Http\Requests;

use App\Domain\Aceites\ChavePixValidator;
use App\Domain\Aceites\DocumentoValidator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * STORY-023 — Validação do completar-cadastro do profissional (CA-2/3/4/5).
 *
 * Documento validado por dígitos conforme o `tipo_pessoa` do perfil (PF→CPF; MEI/PJ→CNPJ).
 * A unicidade do documento NÃO é validada aqui (precisa do hash + resposta genérica anti-enumeração
 * — CA-3): é checada no service. Upload do documento comprobatório é exigido só no submit final;
 * no preview o arquivo é opcional (o contrato não depende dele).
 */
class CompletarCadastroProfissionalRequest extends FormRequest
{
    public function authorize(): bool
    {
        $user = $this->user();

        return $user !== null
            && $user->role === 'profissional'
            && $user->profissionalProfile !== null;
    }

    public function rules(): array
    {
        return [
            'documento' => [
                'required', 'string',
                function (string $attribute, mixed $value, \Closure $fail): void {
                    $tipo = $this->user()->profissionalProfile->tipo_pessoa;
                    if (! DocumentoValidator::valido((string) $value, $tipo)) {
                        $fail($tipo === 'PF'
                            ? 'Informe um CPF válido (com os 11 dígitos).'
                            : 'Informe um CNPJ válido (com os 14 dígitos).');
                    }
                },
            ],
            'funcoes_secundarias' => ['nullable', 'array'],
            'funcoes_secundarias.*' => ['integer', Rule::exists('funcoes', 'id')->where('ativo', true)],
            'raio_max_km' => ['required', 'integer', 'min:1', 'max:500'],
            'preco_hora' => ['required', 'numeric', 'min:1', 'max:100000'],
            'bio' => ['nullable', 'string', 'max:500'],
            'chave_pix' => [
                'required', 'string', 'max:140',
                function (string $attribute, mixed $value, \Closure $fail): void {
                    if (! ChavePixValidator::valida((string) $value)) {
                        $fail('Informe uma chave Pix válida (CPF, CNPJ, e-mail, telefone +55… ou chave aleatória).');
                    }
                },
            ],
            'documento_comprobatorio' => [
                Rule::requiredIf(! $this->ehPreview()),
                'file', 'mimes:jpg,jpeg,png,pdf', 'max:10240', // 10 MB (CA-5)
            ],
        ];
    }

    public function ehPreview(): bool
    {
        return $this->routeIs('usuarios.me.completar-cadastro.preview');
    }

    public function messages(): array
    {
        return [
            'documento.required' => 'Informe seu documento.',
            'raio_max_km.required' => 'Informe o raio máximo de deslocamento.',
            'raio_max_km.integer' => 'O raio deve ser um número em km.',
            'raio_max_km.max' => 'O raio máximo deve ser de até 500 km.',
            'preco_hora.required' => 'Informe seu preço por hora pretendido.',
            'preco_hora.numeric' => 'O preço por hora deve ser um valor numérico.',
            'bio.max' => 'A bio deve ter no máximo 500 caracteres.',
            'chave_pix.required' => 'Informe sua chave Pix.',
            'documento_comprobatorio.required' => 'Envie a foto do seu documento.',
            'documento_comprobatorio.mimes' => 'O documento deve ser JPG, PNG ou PDF.',
            'documento_comprobatorio.max' => 'O documento deve ter no máximo 10 MB.',
        ];
    }
}
