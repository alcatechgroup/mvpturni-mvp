<?php

namespace App\Http\Requests;

use App\Domain\Cadastro\ChavePixValidator;
use App\Domain\Cadastro\DocumentoValidator;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;

/**
 * STORY-023 — Validação do completar cadastro do profissional (CA-2/3/4/5).
 * Documento e chave Pix têm validação contextual (depende do tipo_pessoa do perfil)
 * — feita em after() pois o tipo vem do usuário autenticado, não do payload.
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
            'funcoes_secundarias.*' => ['integer', 'distinct', 'exists:funcoes,id'],
            'raio_max_km' => ['required', 'integer', 'min:1', 'max:500'],
            'preco_hora' => ['required', 'numeric', 'min:1', 'max:100000'],
            'bio' => ['nullable', 'string', 'max:500'],
            'chave_pix' => ['required', 'string', 'max:140'],
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

                if ($this->filled('chave_pix')
                    && ! ChavePixValidator::valida((string) $this->input('chave_pix'))) {
                    $validator->errors()->add('chave_pix', 'Chave Pix inválida. Use CPF, CNPJ, e-mail, telefone (+55...) ou chave aleatória.');
                }
            },
        ];
    }

    /** @return array<string,string> */
    public function messages(): array
    {
        return [
            'documentos_comprobatorios.required' => 'Envie ao menos um documento comprobatório.',
            'documentos_comprobatorios.*.mimes' => 'Cada documento deve ser JPG, PNG ou PDF.',
            'documentos_comprobatorios.*.max' => 'Cada documento deve ter no máximo 10 MB.',
        ];
    }
}
