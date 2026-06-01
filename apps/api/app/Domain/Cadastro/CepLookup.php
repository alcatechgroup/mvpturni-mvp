<?php

namespace App\Domain\Cadastro;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * STORY-024 CA-4 / IDR-024 — Busca de endereço por CEP via ViaCEP.
 *
 * Fail-soft por contrato: NUNCA lança. Qualquer falha (CEP malformado, inexistente,
 * timeout, 5xx) retorna null — o completar cadastro degrada para entrada manual e não é
 * bloqueado. Falhas de integração (rede/HTTP) são logadas como `cadastro.cep_lookup_falhou`.
 */
class CepLookup
{
    /**
     * @return array{cep?:string,logradouro:string,bairro:string,cidade:string,uf:string}|null
     */
    public function buscar(string $cep): ?array
    {
        $digitos = preg_replace('/\D/', '', $cep) ?? '';

        // CEP brasileiro tem 8 dígitos — fora disso nem chama a API.
        if (strlen($digitos) !== 8) {
            return null;
        }

        try {
            $resposta = Http::timeout((int) config('services.viacep.timeout', 4))
                ->acceptJson()
                ->get(rtrim((string) config('services.viacep.base_url'), '/')."/{$digitos}/json/");

            if ($resposta->failed()) {
                Log::warning('cadastro.cep_lookup_falhou', ['status' => $resposta->status()]);

                return null;
            }

            $dados = $resposta->json();

            // ViaCEP devolve {"erro": true} para CEP inexistente.
            if (! is_array($dados) || ($dados['erro'] ?? false)) {
                return null;
            }

            return [
                'cep' => $dados['cep'] ?? $cep,
                'logradouro' => (string) ($dados['logradouro'] ?? ''),
                'bairro' => (string) ($dados['bairro'] ?? ''),
                'cidade' => (string) ($dados['localidade'] ?? ''),
                'uf' => (string) ($dados['uf'] ?? ''),
            ];
        } catch (Throwable $e) {
            // Indisponibilidade do fornecedor externo não pode derrubar o cadastro (CA-4).
            Log::warning('cadastro.cep_lookup_falhou', ['erro' => $e->getMessage()]);

            return null;
        }
    }
}
