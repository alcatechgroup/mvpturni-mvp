<?php

namespace App\Services\Disputas;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * STORY-096 / ADR-020 (Decisão 3) / IDR-032 — cliente do canal service-to-service admin→api do
 * comando "pagar integral". A captura+Pix é single-sourced na api (disparada por um evento
 * in-process que o backoffice não emite); o admin é CLIENTE deste endpoint INTERNO.
 *
 * Autenticação do CANAL: segredo compartilhado no header `X-Internal-Token` (fail-secure — token
 * ausente na config → não faz request). A IDENTIDADE do admin (`admin_id`) viaja no corpo e é
 * re-verificada (`isAdmin()`) na api. As respostas são mapeadas para `ResultadoResolucao`:
 *   200 → Ok; 422 `estado_invalido` → Concorrente; qualquer outra → Erro (sem efeito duplicado).
 */
class ResolverDisputaClient
{
    /** Folga de rede para um comando síncrono que move dinheiro (a captura em si é assíncrona). */
    private const TIMEOUT_SEGUNDOS = 10;

    public function resolver(string $turnoId, string $adminId, string $notaAdmin): ResultadoResolucao
    {
        $token = (string) config('services.internal.token');
        if ($token === '') {
            Log::error('ResolverDisputaClient: INTERNAL_SERVICE_TOKEN ausente — canal admin→api indisponível.');

            return ResultadoResolucao::Erro;
        }

        $base = rtrim((string) config('services.api.internal_url'), '/');
        $url = "{$base}/api/internal/turnos/{$turnoId}/resolver-disputa";

        try {
            $resposta = Http::withHeaders(['X-Internal-Token' => $token])
                ->acceptJson()
                ->timeout(self::TIMEOUT_SEGUNDOS)
                ->post($url, ['admin_id' => $adminId, 'nota_admin' => $notaAdmin]);
        } catch (ConnectionException $e) {
            Log::error('ResolverDisputaClient: falha de conexão com a api.', ['turno_id' => $turnoId, 'erro' => $e->getMessage()]);

            return ResultadoResolucao::Erro;
        } catch (Throwable $e) {
            Log::error('ResolverDisputaClient: erro inesperado ao chamar a api.', ['turno_id' => $turnoId, 'erro' => $e->getMessage()]);

            return ResultadoResolucao::Erro;
        }

        if ($resposta->successful()) {
            return ResultadoResolucao::Ok;
        }

        // 422 `estado_invalido`: o turno já não está em `em_disputa` (outro admin resolveu, ou
        // reprocesso) — concorrência, não erro de operação. Demais 4xx/5xx → erro genérico.
        if ($resposta->status() === 422 && $resposta->json('motivo') === 'estado_invalido') {
            return ResultadoResolucao::Concorrente;
        }

        Log::warning('ResolverDisputaClient: api recusou a resolução.', [
            'turno_id' => $turnoId, 'status' => $resposta->status(), 'motivo' => $resposta->json('motivo'),
        ]);

        return ResultadoResolucao::Erro;
    }
}
