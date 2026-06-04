<?php

namespace App\Domain\Pagamento\Pagarme;

use App\Domain\Pagamento\Exceptions\CapturaFalhou;
use App\Domain\Pagamento\Exceptions\GatewayIndisponivel;
use App\Domain\Pagamento\Exceptions\LiberacaoFalhou;
use App\Domain\Pagamento\Exceptions\OperacaoPagamentoException;
use App\Domain\Pagamento\Exceptions\PixFalhou;
use App\Domain\Pagamento\Exceptions\PreAutorizacaoNegada;
use App\Domain\Pagamento\GatewayPagamento;
use App\Domain\Pagamento\ResultadoOperacao;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Models\PagamentoOperacao;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;

/**
 * STORY-056 / ADR-016 (CA-3, Decisão 2A, 3A). ÚNICO lugar que conhece o Pagar.me. Implementa
 * GatewayPagamento sobre o client Http do Laravel (ADR-001). O driver (`mock|sandbox|live`)
 * só troca `base_url` + credencial em config — NÃO há ramificação de código por driver, o que
 * mantém o contract test (STORY-056-B) guardando exatamente o caminho de produção.
 *
 * - `external_reference` carrega o UUID do turno como string (ADR-018, CA-5) — ida-e-volta.
 * - A chave idempotente viaja como header `Idempotency-Key` (defesa dupla — ADR-016 b).
 * - Valores em string decimal "123.45" → convertidos para centavos inteiros NA fronteira.
 * - Erro: 5xx/rede → GatewayIndisponivel (recuperável); 4xx → exceção fatal por operação.
 *   Nenhum HTTP do Pagar.me sobe daqui (F1).
 */
class PagarmeGateway implements GatewayPagamento
{
    public function preAutorizar(string $turnoId, string $totalContratante, string $meioPagamentoToken): ResultadoOperacao
    {
        $body = [
            'amount' => self::centavos($totalContratante),
            'external_reference' => $turnoId,
            'payment_token' => $meioPagamentoToken,
            'capture' => false, // pré-autoriza sem capturar (domain/pagamento.md §ciclo 1)
        ];

        $resp = $this->enviar('POST', '/orders', $body, TipoOperacaoPagamento::PreAutorizacao, $turnoId);

        return $this->resultado(TipoOperacaoPagamento::PreAutorizacao, $resp);
    }

    public function capturar(string $turnoId): ResultadoOperacao
    {
        $chargeId = $this->chargeIdDoTurno($turnoId);
        $resp = $this->enviar('POST', "/charges/{$chargeId}/capture", [], TipoOperacaoPagamento::Captura, $turnoId);

        return $this->resultado(TipoOperacaoPagamento::Captura, $resp);
    }

    public function capturarParcial(string $turnoId, string $valorRevisado): ResultadoOperacao
    {
        $chargeId = $this->chargeIdDoTurno($turnoId);
        $body = ['amount' => self::centavos($valorRevisado)];
        $resp = $this->enviar('POST', "/charges/{$chargeId}/capture", $body, TipoOperacaoPagamento::CapturaParcial, $turnoId);

        return $this->resultado(TipoOperacaoPagamento::CapturaParcial, $resp);
    }

    public function liberar(string $turnoId): ResultadoOperacao
    {
        $chargeId = $this->chargeIdDoTurno($turnoId);
        $resp = $this->enviar('POST', "/charges/{$chargeId}/cancel", [], TipoOperacaoPagamento::Liberacao, $turnoId);

        return $this->resultado(TipoOperacaoPagamento::Liberacao, $resp);
    }

    public function transferirPix(string $turnoId, string $valorProfissional, string $chavePix): ResultadoOperacao
    {
        $body = [
            'amount' => self::centavos($valorProfissional),
            'pix_key' => $chavePix, // dado sensível — só na request ao provedor, nunca logado
            'external_reference' => $turnoId,
        ];

        $resp = $this->enviar('POST', '/transfers', $body, TipoOperacaoPagamento::Pix, $turnoId);

        return $this->resultado(TipoOperacaoPagamento::Pix, $resp);
    }

    /** Client configurado por driver + Idempotency-Key da operação (ADR-016 b/c). */
    private function client(TipoOperacaoPagamento $tipo, string $turnoId): PendingRequest
    {
        $cfg = config('services.pagarme');

        return Http::baseUrl(rtrim((string) $cfg['base_url'], '/'))
            ->timeout((int) $cfg['timeout'])
            ->withToken((string) $cfg['secret_key'])
            ->withHeaders(['Idempotency-Key' => $tipo->chaveIdempotente($turnoId)])
            ->acceptJson()
            ->asJson();
    }

    private function enviar(string $metodo, string $path, array $body, TipoOperacaoPagamento $tipo, string $turnoId): Response
    {
        try {
            $resp = $this->client($tipo, $turnoId)->send($metodo, $path, ['json' => $body]);
        } catch (ConnectionException $e) {
            throw new GatewayIndisponivel("Pagar.me inacessível: {$e->getMessage()}", ['operacao' => $tipo->value, 'turno_id' => $turnoId]);
        }

        if ($resp->failed()) {
            throw $this->mapearErro($tipo, $resp);
        }

        return $resp;
    }

    /** Mapeia falha HTTP → exceção de domínio (Decisão 3A). 5xx = recuperável; 4xx = fatal. */
    private function mapearErro(TipoOperacaoPagamento $tipo, Response $resp): OperacaoPagamentoException
    {
        $contexto = ['operacao' => $tipo->value, 'http_status' => $resp->status()];

        // Falha transiente: o worker pode retentar com backoff (ADR-005 d).
        if ($resp->serverError()) {
            return new GatewayIndisponivel("Pagar.me retornou {$resp->status()}", $contexto);
        }

        // Falha fatal de negócio (4xx): mensagem do provedor (sem PII) + exceção por operação.
        $mensagem = (string) ($resp->json('message') ?? "Pagar.me recusou a operação ({$resp->status()})");

        return match ($tipo) {
            TipoOperacaoPagamento::PreAutorizacao => new PreAutorizacaoNegada($mensagem, contexto: $contexto),
            TipoOperacaoPagamento::Captura, TipoOperacaoPagamento::CapturaParcial => new CapturaFalhou($mensagem, contexto: $contexto),
            TipoOperacaoPagamento::Liberacao => new LiberacaoFalhou($mensagem, contexto: $contexto),
            TipoOperacaoPagamento::Pix => new PixFalhou($mensagem, contexto: $contexto),
        };
    }

    private function resultado(TipoOperacaoPagamento $tipo, Response $resp): ResultadoOperacao
    {
        $json = $resp->json() ?? [];
        $charge = $json['charges'][0] ?? [];

        return new ResultadoOperacao(
            tipo: $tipo,
            status: StatusOperacaoPagamento::Concluida,
            pagarmeOrderId: $json['id'] ?? null,
            pagarmeChargeId: $charge['id'] ?? ($tipo->value === 'pix' ? null : ($json['id'] ?? null)),
            pagarmeTransferId: $tipo === TipoOperacaoPagamento::Pix ? ($json['id'] ?? null) : null,
            raw: $json,
        );
    }

    /** Recupera o charge_id da pré-autorização do turno (correlação em pagamento_operacoes). */
    private function chargeIdDoTurno(string $turnoId): string
    {
        $preAuth = PagamentoOperacao::where('turno_id', $turnoId)
            ->where('tipo_operacao', TipoOperacaoPagamento::PreAutorizacao)
            ->first();

        $chargeId = $preAuth?->pagarme_charge_id;

        if ($chargeId === null) {
            throw new CapturaFalhou("Turno {$turnoId} não tem pré-autorização com charge_id para correlacionar", contexto: ['turno_id' => $turnoId]);
        }

        return $chargeId;
    }

    /**
     * "123.45" → 12345 centavos (Pagar.me usa inteiro). Parsing por STRING, sem ponto
     * flutuante e sem bcmath (ausente na imagem): separa parte inteira e decimal.
     */
    private static function centavos(string $valorDecimal): int
    {
        $partes = explode('.', trim($valorDecimal), 2);
        $inteiro = (int) $partes[0];
        $decimais = str_pad(substr($partes[1] ?? '', 0, 2), 2, '0'); // 2 casas (decimal:2)

        return $inteiro * 100 + (int) $decimais;
    }
}
