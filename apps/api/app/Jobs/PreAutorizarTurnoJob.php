<?php

namespace App\Jobs;

use App\Domain\Pagamento\Exceptions\GatewayIndisponivel;
use App\Domain\Pagamento\Exceptions\PreAutorizacaoNegada;
use App\Domain\Pagamento\GatewayPagamento;
use App\Domain\Pagamento\OperacaoIdempotente;
use App\Enums\TipoOperacaoPagamento;
use App\Events\Pagamento\PagamentoPreAutorizacaoFalhou;
use App\Events\Pagamento\PagamentoPreAutorizado;
use App\Models\AuditLog;
use App\Models\Turno;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * STORY-058 (CA-6, CA-7) — pré-autoriza o `total_contratante` do turno recém-confirmado, de
 * forma assíncrona no `worker` (fila database — ADR-002) e idempotente (OperacaoIdempotente,
 * STORY-056/ADR-016: clique-duplo e retry NÃO duplicam dinheiro).
 *
 * Desfechos:
 *  - sucesso → audit `pagamento.pre_autorizado` + evento PagamentoPreAutorizado (STORY-067);
 *  - recusa fatal (PreAutorizacaoNegada) → audit `pagamento.pre_autorizacao_falhou` + evento
 *    PagamentoPreAutorizacaoFalhou; o admin enxerga via `pagamento_operacoes` (status falhou).
 *    SEM retry automático (fora de escopo — espelha PDR-010);
 *  - indisponibilidade (GatewayIndisponivel) → relança: o worker retenta com backoff.
 *
 * `meioPagamentoToken`: o fluxo real de tokenização do meio de pagamento fica para a wave da
 * integração Pagar.me (ADR-016 §consequências). No MVP o fake (PDR-017) honra qualquer token;
 * usamos um stub determinístico por contratante.
 */
class PreAutorizarTurnoJob implements ShouldQueue
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

        if ($turno === null) {
            return; // defensivo: turno sumiu (nunca esperado — restrictOnDelete)
        }

        $token = 'tok_mvp_'.$turno->contratante_id; // stub PDR-017 (ver docblock)

        try {
            $resultado = $runner->executar(
                $turno->id,
                TipoOperacaoPagamento::PreAutorizacao,
                ['total_contratante' => $turno->total_contratante], // sem PII (token mascarado fora)
                fn () => $gateway->preAutorizar($turno->id, $turno->total_contratante, $token),
            );
        } catch (GatewayIndisponivel $e) {
            throw $e; // transiente: worker retenta com backoff (tries/backoff acima)
        } catch (PreAutorizacaoNegada $e) {
            $this->registrarFalha($turno, $e->getMessage());

            return; // fatal: registrado e alertado; sem retry automático
        }

        AuditLog::create([
            'actor_id' => null, // operação do sistema (worker)
            'action' => 'pagamento.pre_autorizado',
            'target_type' => 'Turno',
            'target_id' => $turno->id,
            'payload' => [
                'tipo_operacao' => TipoOperacaoPagamento::PreAutorizacao->value,
                'total_contratante' => $turno->total_contratante,
                'pagarme_charge_id' => $resultado->pagarmeChargeId,
            ],
        ]);

        PagamentoPreAutorizado::dispatch($turno->id, $resultado->pagarmeChargeId);
    }

    /** Esgotou as tentativas com o gateway indisponível: registra o desfecho como falha. */
    public function failed(?\Throwable $e): void
    {
        $turno = Turno::find($this->turnoId);

        if ($turno !== null) {
            $this->registrarFalha($turno, $e?->getMessage() ?? 'gateway indisponível (tentativas esgotadas)');
        }
    }

    private function registrarFalha(Turno $turno, string $motivo): void
    {
        AuditLog::create([
            'actor_id' => null,
            'action' => 'pagamento.pre_autorizacao_falhou',
            'target_type' => 'Turno',
            'target_id' => $turno->id,
            'payload' => ['motivo' => $motivo],
        ]);

        PagamentoPreAutorizacaoFalhou::dispatch($turno->id, $motivo);
    }
}
