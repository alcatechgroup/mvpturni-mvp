<?php

namespace App\Http\Requests;

use App\Domain\Cadastro\DocumentoValidator;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * STORY-024 — Validação do completar cadastro do contratante (CA-2/3/5).
 * Contratante é sempre PJ → CNPJ (dígitos verificadores em after(), via DocumentoValidator).
 * Campos opcionais (apelido, turnos, cultura, site, redes, contatos, logo) seguem a estória.
 */
class CompletarCadastroContratanteRequest extends FormRequest
{
    /** Faixas de quantidade de funcionários (domain/usuario.md §Contratante). */
    private const FAIXAS_FUNCIONARIOS = ['1-10', '11-50', '51-200', '200+'];

    public function authorize(): bool
    {
        $user = $this->user();

        // Só contratante liberado, welcome visto e cadastro ainda não concluído (await_cadastro).
        return $user !== null
            && $user->isContratante()
            && $user->funnelState() === 'await_cadastro';
    }

    /** @return array<string,mixed> */
    public function rules(): array
    {
        return [
            'cnpj' => ['required', 'string', 'max:20'],
            // Endereço estruturado.
            'cep' => ['required', 'string', 'regex:/^\d{5}-?\d{3}$/'],
            'logradouro' => ['required', 'string', 'max:180'],
            'numero' => ['required', 'string', 'max:20'],
            'bairro' => ['required', 'string', 'max:120'],
            'cidade' => ['required', 'string', 'max:120'],
            'uf' => ['required', 'string', 'size:2'],
            'complemento' => ['nullable', 'string', 'max:120'],
            // Perfil do estabelecimento.
            'apelido_estabelecimento' => ['nullable', 'string', 'max:60'],
            'segmento' => ['required', 'string', 'max:120'],
            'ano_fundacao' => ['required', 'integer', 'min:1900', 'max:'.((int) date('Y'))],
            'qtd_funcionarios' => ['required', Rule::in(self::FAIXAS_FUNCIONARIOS)],
            'turnos_operacao' => ['nullable', 'string', 'max:500'],
            'cultura_valores' => ['nullable', 'string', 'max:1000'],
            'site' => ['nullable', 'url', 'max:200'],
            'redes_sociais' => ['nullable', 'array'],
            'redes_sociais.*' => ['nullable', 'string', 'max:200'],
            // Lista dinâmica de contatos adicionais (≥0). Numa linha, nome+função obrigatórios.
            'contatos_adicionais' => ['nullable', 'array', 'max:10'],
            'contatos_adicionais.*.nome' => ['required', 'string', 'max:120'],
            'contatos_adicionais.*.funcao' => ['required', 'string', 'max:80'],
            'contatos_adicionais.*.telefone' => ['nullable', 'string', 'max:20'],
            // Logo opcional (CA-5).
            'logo' => ['nullable', 'file', 'mimes:jpg,jpeg,png', 'max:5120'],
        ];
    }

    public function after(): array
    {
        return [
            function (Validator $validator) {
                if ($this->filled('cnpj') && ! DocumentoValidator::cnpjValido((string) $this->input('cnpj'))) {
                    $validator->errors()->add('cnpj', 'Informe um CNPJ válido.');
                }
            },
        ];
    }

    /** @return array<string,string> */
    public function messages(): array
    {
        return [
            'uf.size' => 'Informe a UF com 2 letras (ex.: SP).',
            'cep.regex' => 'Informe um CEP válido (00000-000).',
            'qtd_funcionarios.in' => 'Selecione uma faixa de funcionários válida.',
            'logo.mimes' => 'A logo deve ser JPG ou PNG.',
            'logo.max' => 'A logo deve ter no máximo 5 MB.',
            'contatos_adicionais.*.nome.required' => 'Informe o nome do contato.',
            'contatos_adicionais.*.funcao.required' => 'Informe a função do contato.',
        ];
    }
}
