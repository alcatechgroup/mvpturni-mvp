<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

/**
 * STORY-018 — Validação do pré-cadastro público de contratante.
 *
 * Espelha a régua da STORY-017 (mesma defesa em profundidade), adaptada ao contratante:
 * dados do responsável + do estabelecimento. Contratante é sempre PJ — NÃO há `tipo_pessoa`
 * e NÃO se coleta CNPJ/endereço aqui (CA-13; CNPJ vai na STORY-024).
 *
 * Importante (CA-4): a unicidade do e-mail NÃO é validada aqui com a regra `unique`,
 * porque um erro de campo "e-mail já cadastrado" permite enumeração. A unicidade é
 * verificada no controller e responde com mensagem genérica.
 *
 * Defesa em profundidade (CA-5): o aceite dos Termos é `accepted` no servidor. Foto
 * validada por MIME e tamanho no servidor (CA-6). `tipo_operacao` é um enum fechado
 * (lista estática — IDR-012), validado com `Rule::in`.
 */
class StoreContratantePreCadastroRequest extends FormRequest
{
    /** Tipos de operação aceitos (domain/usuario.md §Contratante). Enum estático — IDR-012. */
    public const TIPOS_OPERACAO = ['restaurante', 'bar', 'hotel', 'evento', 'catering', 'outro'];

    public function authorize(): bool
    {
        return true; // Rota pública (sem auth) — pré-cadastro.
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'min:3', 'max:120'],
            'email' => ['required', 'string', 'email:rfc', 'max:255'],
            'telefone' => ['required', 'string', 'regex:/^\(?\d{2}\)?[\s-]?9?\d{4}[\s-]?\d{4}$/'],
            'nome_estabelecimento' => ['required', 'string', 'min:2', 'max:200'],
            'tipo_operacao' => ['required', Rule::in(self::TIPOS_OPERACAO)],
            'cidade' => ['required', 'string', 'max:120'],
            'foto' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png', 'max:5120'],
            'password' => ['required', 'string', 'confirmed', Password::min(10)->mixedCase()->numbers()],
            'termos_aceitos' => ['required', 'accepted'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => 'Informe o nome do responsável.',
            'name.min' => 'O nome deve ter ao menos 3 caracteres.',
            'name.max' => 'O nome deve ter no máximo 120 caracteres.',
            'email.required' => 'Informe seu e-mail.',
            'email.email' => 'Informe um e-mail válido (ex.: nome@dominio.com).',
            'telefone.required' => 'Informe seu telefone.',
            'telefone.regex' => 'Informe um telefone válido com DDD (ex.: (11) 91234-5678).',
            'nome_estabelecimento.required' => 'Informe o nome do estabelecimento.',
            'nome_estabelecimento.min' => 'O nome do estabelecimento deve ter ao menos 2 caracteres.',
            'nome_estabelecimento.max' => 'O nome do estabelecimento deve ter no máximo 200 caracteres.',
            'tipo_operacao.required' => 'Selecione o tipo de operação.',
            'tipo_operacao.in' => 'Selecione um tipo de operação válido da lista.',
            'cidade.required' => 'Informe a cidade.',
            'foto.required' => 'Envie uma foto.',
            'foto.image' => 'A foto deve ser uma imagem JPG ou PNG.',
            'foto.mimes' => 'A foto deve estar em JPG ou PNG.',
            'foto.max' => 'A foto deve ter no máximo 5 MB.',
            'password.required' => 'Crie uma senha.',
            'password.min' => 'A senha deve ter ao menos 10 caracteres.',
            'password.confirmed' => 'A confirmação de senha não corresponde.',
            'termos_aceitos.required' => 'É necessário aceitar os Termos de Uso e a Política de Privacidade.',
            'termos_aceitos.accepted' => 'É necessário aceitar os Termos de Uso e a Política de Privacidade.',
        ];
    }
}
