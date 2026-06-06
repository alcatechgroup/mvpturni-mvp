<?php

namespace App\Jobs;

use App\Domain\Pagamento\Exceptions\CapturaFalhou;
use App\Domain\Pagamento\Exceptions\GatewayIndisponivel;
use App\Domain\Pagamento\Exceptions\PixFalhou as PixFalhouException;
use App\Domain\Pagamento\GatewayPagamento;
use App\Domain\Pagamento\OperacaoIdempotente;
use App\Domain\Pagamento\ResultadoOperacao;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Enums\TurnoStatus;
use App\Events\Pagamento\PagamentoCapturado;
use App\Models\AuditLog;
use App\Models\PagamentoOperacao;
use App\Models\PixFalha;
use App\Models\Turno;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * STORY-065 (CA-1..4, 9) — o ciclo financeiro pós-turno: `capturar` o total pré-autorizado
 * do contratante e, em sequência, `transferirPix` do valor integral ao profissional
 * (domain/pagamento.md §3). Assíncrono no worker (fila database — ADR-002), idempotente
 * por operação (`captura:{turno_id}` / `pix:{turno_id}` — STORY-056/ADR-016: retry e
 * redispatch NÃO duplicam dinheiro).
 *
 * Desfechos:
 *  - captura ok → audit `pagamento.capturado` + evento PagamentoCapturado (CA-2; STORY-067);
 *  - captura falha fatal (CapturaFalhou) → audit `pagamento.captura_falhou` + operação
 *    `falhou`; Pix NÃO é tentado (sem dinheiro capturado não há o que repassar);
 *  - Pix ok na resposta síncrona → NADA de `pix.enviado` aqui: a fonte de verdade é o
 *    webhook do gateway (CA-6 — HandlePixEnviado grava o audit que liga timeline e card);
 *  - Pix falha fatal (PixFalhou) → UMA tentativa (PDR-010): audit `pix.falhou` + caso em
 *    `pix_falhas` (fila do admin), com a razão retornada pelo gateway;
 *  - chave Pix ausente no perfil (EPIC-001 é pré-requisito, mas defendemos) → mesmo
 *    desfecho de falha, sem chamar o gateway;
 *  - GatewayIndisponivel → relança: o worker retenta com backoff; o curto-circuito da
 *    idempotência reaproveita a captura concluída na retentativa.
 *  - CA-9: turno fora de `finalizado` (cancelado, em disputa, etc.) → no-op; a liberação
 *    da pré-autorização é da STORY-066.
 */
class CapturarEPagarTurnoJob implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public array $backoff = [10, 30, 60];

    public int $timeout = 30;

    public function __construct(public readonly string $turnoId)
    {
        $this->onConnection('database');
    }

    public function handle(OperacaoIdempotente $runner, GatewayPagamento $gateway): void
    {
        $turno = Turno::find($this->turnoId);

        if ($turno === null || $turno->status !== TurnoStatus::Finalizado) {
            return; // CA-9 — captura só existe para turno finalizado (guard re-verificado aqui)
        }

        $resultadoCaptura = $this->capturar($runner, $gateway, $turno);

        if ($resultadoCaptura === null) {
            return; // falha fatal de captura já registrada; sem Pix
        }

        $this->transferirPix($runner, $gateway, $turno);
    }

    /** Esgotou as tentativas (gateway indisponível): registra o ponto em que parou. */
    public function failed(?\Throwable $e): void
    {
        $turno = Turno::find($this->turnoId);

        if ($turno === null) {
            return;
        }

        $motivo = $e?->getMessage() ?? 'gateway indisponível (tentativas esgotadas)';

        $capturaConcluida = PagamentoOperacao::where('turno_id', $turno->id)
            ->where('tipo_operacao', TipoOperacaoPagamento::Captura)
            ->where('status', StatusOperacaoPagamento::Concluida)
            ->exists();

        if ($capturaConcluida) {
            // Dinheiro capturado e Pix não saiu — exatamente o caso de tratamento manual.
            $this->registrarPixFalha($turno, "gateway indisponível — {$motivo}");

            return;
        }

        AuditLog::create([
            'actor_id' => null,
            'action' => 'pagamento.captura_falhou',
            'target_type' => 'Turno',
            'target_id' => $turno->id,
            'payload' => ['motivo' => $motivo],
        ]);
    }

    /** CA-2 — captura idempotente. Devolve null em falha fatal (já registrada). */
    private function capturar(OperacaoIdempotente $runner, GatewayPagamento $gateway, Turno $turno): ?ResultadoOperacao
    {
        try {
            $resultado = $runner->executar(
                $turno->id,
                TipoOperacaoPagamento::Captura,
                ['valor_capturado' => $turno->total_contratante],
                fn () => $gateway->capturar($turno->id),
            );
        } catch (GatewayIndisponivel $e) {
            throw $e; // transiente: worker retenta com backoff
        } catch (CapturaFalhou $e) {
            AuditLog::create([
                'actor_id' => null,
                'action' => 'pagamento.captura_falhou',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => ['motivo' => $e->getMessage()],
            ]);

            return null; // fatal: sem retry automático; Pix não é tentado
        }

        // Audit + evento SÓ na primeira conclusão (o curto-circuito da idempotência repete
        // o resultado, não o efeito — redispatch não duplica a linha da timeline).
        if (! AuditLog::where('action', 'pagamento.capturado')->where('target_id', $turno->id)->exists()) {
            AuditLog::create([
                'actor_id' => null, // operação do sistema (worker)
                'action' => 'pagamento.capturado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => [
                    'tipo_operacao' => TipoOperacaoPagamento::Captura->value,
                    'pagarme_charge_id' => $resultado->pagarmeChargeId,
                    'valor_capturado' => $turno->total_contratante,
                ],
            ]);

            PagamentoCapturado::dispatch(
                $turno->id,
                (string) $resultado->pagarmeChargeId,
                (string) $turno->total_contratante,
                CarbonImmutable::now(),
            );
        }

        return $resultado;
    }

    /** CA-3 — Pix do valor integral ao profissional. PDR-010: UMA tentativa. */
    private function transferirPix(OperacaoIdempotente $runner, GatewayPagamento $gateway, Turno $turno): void
    {
        // Chave do perfil (EPIC-001). Cast `encrypted` descriptografa na leitura; daqui
        // para baixo ela só viaja para o adapter — nunca para log/payload (ADR-016 g).
        $chavePix = $turno->profissional?->profissionalProfile?->chave_pix_encrypted;

        if ($chavePix === null || $chavePix === '') {
            $this->registrarPixFalha($turno, 'chave Pix ausente no perfil do profissional');

            return;
        }

        try {
            $runner->executar(
                $turno->id,
                TipoOperacaoPagamento::Pix,
                ['valor' => $turno->valor, 'chave_pix' => '***'], // mascarada na origem
                fn () => $gateway->transferirPix($turno->id, $turno->valor, $chavePix),
            );
        } catch (GatewayIndisponivel $e) {
            throw $e; // transiente: retentativa reaproveita a captura (curto-circuito)
        } catch (PixFalhouException $e) {
            $this->registrarPixFalha($turno, $e->getMessage()); // PDR-010 — uma tentativa
        }

        // Sucesso síncrono: SEM audit aqui — `pix.enviado` nasce do webhook (CA-6).
    }

    /** Falha de Pix → audit `pix.falhou` + caso na fila do admin (CA-5/PDR-010). */
    private function registrarPixFalha(Turno $turno, string $razao): void
    {
        PixFalha::registrar($turno, $razao);

        AuditLog::create([
            'actor_id' => null,
            'action' => 'pix.falhou',
            'target_type' => 'Turno',
            'target_id' => $turno->id,
            'payload' => ['razao' => $razao],
        ]);
    }
}
