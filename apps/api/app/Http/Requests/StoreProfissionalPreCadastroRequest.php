<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

/**
 * STORY-017 — Validação do pré-cadastro público de profissional.
 *
 * Importante (CA-4): a unicidade do e-mail NÃO é validada aqui com a regra `unique`,
 * porque um erro de campo "e-mail já cadastrado" permite enumeração. A unicidade é
 * verificada no controller e responde com mensagem genérica.
 *
 * Defesa em profundidade (CA-5): o aceite dos Termos é `accepted` no servidor, além
 * do bloqueio client-side. Foto validada por MIME e tamanho no servidor (CA-6) —
 * não se confia no client.
 */
class StoreProfissionalPreCadastroRequest extends FormRequest
{
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
            'cidade' => ['required', 'string', 'max:120'],
            'bairro' => ['required', 'string', 'max:120'],
            'funcao_id' => ['required', 'integer', Rule::exists('funcoes', 'id')->where('ativo', true)],
            'tipo_pessoa' => ['required', Rule::in(['PF', 'MEI', 'PJ'])],
            'foto' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png', 'max:5120'],
            'password' => ['required', 'string', 'confirmed', Password::min(10)->mixedCase()->numbers()],
            'termos_aceitos' => ['required', 'accepted'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => 'Informe seu nome completo.',
            'name.min' => 'O nome deve ter ao menos 3 caracteres.',
            'name.max' => 'O nome deve ter no máximo 120 caracteres.',
            'email.required' => 'Informe seu e-mail.',
            'email.email' => 'Informe um e-mail válido (ex.: nome@dominio.com).',
            'telefone.required' => 'Informe seu telefone.',
            'telefone.regex' => 'Informe um telefone válido com DDD (ex.: (11) 91234-5678).',
            'cidade.required' => 'Informe sua cidade.',
            'bairro.required' => 'Informe seu bairro.',
            'funcao_id.required' => 'Selecione a função pretendida.',
            'funcao_id.exists' => 'Selecione uma função válida da lista.',
            'tipo_pessoa.required' => 'Selecione o tipo de pessoa (PF, MEI ou PJ).',
            'tipo_pessoa.in' => 'Tipo de pessoa inválido. Escolha PF, MEI ou PJ.',
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
