<?php

namespace App\Http\Requests;

use App\Domain\Cadastro\DocumentoValidator;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;

/**
 * STORY-023 — Validação do completar cadastro do profissional (CA-2/3/4/5).
 * O documento tem validação contextual (depende do tipo_pessoa do perfil) — feita em
 * after(), pois o tipo vem do usuário autenticado, não do payload. A chave Pix é, por
 * ora, validada só por comprimento mínimo (≥6); a validação de formato por tipo
 * (CPF/CNPJ/e-mail/telefone/aleatória — ver ChavePixValidator) será tratada à parte.
 */
class CompletarCadastroProfissionalRequest extends FormRequest
{
    public function authorize(): bool
    {
        $user = $this->user();

        // Só profissional liberado, welcome visto e cadastro ainda não concluído (await_cadastro).
        return $user !== null
            && $user->isProfissional()
            && $user->funnelState() === 'await_cadastro';
    }

    /** @return array<string,mixed> */
    public function rules(): array
    {
        return [
            'documento' => ['required', 'string', 'max:20'],
            'funcoes_secundarias' => ['nullable', 'array', 'max:10'],
            'funcoes_secundarias.*' => ['bail', 'uuid', 'distinct', 'exists:funcoes,id'],
            'raio_max_km' => ['required', 'integer', 'min:1', 'max:500'],
            'preco_hora' => ['required', 'numeric', 'min:1', 'max:100000'],
            'bio' => ['nullable', 'string', 'max:500'],
            // Validação simplificada (≥6 chars). Formato por tipo de chave: tratado à parte.
            'chave_pix' => ['required', 'string', 'min:6', 'max:140'],
            'documentos_comprobatorios' => ['required', 'array', 'min:1', 'max:5'],
            'documentos_comprobatorios.*' => ['file', 'mimes:jpg,jpeg,png,pdf', 'max:10240'],
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                $tipoPessoa = $this->user()->profissionalProfile->tipo_pessoa;

                if ($this->filled('documento')
                    && ! DocumentoValidator::validarParaTipoPessoa($tipoPessoa, (string) $this->input('documento'))) {
                    $doc = DocumentoValidator::tipoDocumento($tipoPessoa);
                    $validator->errors()->add('documento', "Informe um {$doc} válido.");
                }
            },
        ];
    }

    /** @return array<string,string> */
    public function messages(): array
    {
        return [
            'chave_pix.min' => 'A chave Pix deve ter ao menos 6 caracteres.',
            'documentos_comprobatorios.required' => 'Envie ao menos um documento comprobatório.',
            'documentos_comprobatorios.*.mimes' => 'Cada documento deve ser JPG, PNG ou PDF.',
            'documentos_comprobatorios.*.max' => 'Cada documento deve ter no máximo 10 MB.',
        ];
    }
}
