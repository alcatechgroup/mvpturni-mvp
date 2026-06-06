<?php

namespace App\Jobs;

use App\Domain\Pagamento\Exceptions\GatewayIndisponivel;
use App\Domain\Pagamento\Exceptions\LiberacaoFalhou;
use App\Domain\Pagamento\GatewayPagamento;
use App\Domain\Pagamento\OperacaoIdempotente;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Enums\TurnoStatus;
use App\Models\AuditLog;
use App\Models\PagamentoOperacao;
use App\Models\PixFalha;
use App\Models\Turno;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * STORY-066 (CA-2..CA-4, CA-6) — libera a pré-autorização do contratante quando o turno sai
 * do caminho do dinheiro: cancelamento (qualquer lado) ou no-show. Assíncrono no worker
 * (fila database — ADR-002), idempotente (`liberacao:{turno_id}` — STORY-056/ADR-016:
 * cancelamento + no-show no mesmo turno, ou retry do worker, NÃO chamam o gateway 2×).
 *
 * Desfechos (espelho do CapturarEPagarTurnoJob/065):
 *  - sucesso → audit `pagamento.liberado` com o motivo ('cancelamento' | 'no_show' — CA-6)
 *    UMA vez (o curto-circuito da idempotência repete o resultado, não o efeito);
 *  - falha fatal (LiberacaoFalhou) → audit `pagamento.liberacao_falhou` + caso tipo
 *    `liberacao` na fila operacional do admin (CA-4 — mesma fila da STORY-065,
 *    generalizada para "Falhas de pagamento");
 *  - GatewayIndisponivel → relança: o worker retenta com backoff;
 *  - guard: só age sobre turno em estado que deve liberar (cancelado_* | no_show_pro) —
 *    re-verificado aqui, nunca confiado ao chamador.
 */
class LiberarPreAutorizacaoJob implements ShouldQueue
{
    use Queueable;

    public int $tries = 3;

    public array $backoff = [10, 30, 60];

    public int $timeout = 30;

    /** @param  'cancelamento'|'no_show'  $motivo */
    public function __construct(
        public readonly string $turnoId,
        public readonly string $motivo,
    ) {
        $this->onConnection('database');
    }

    public function handle(OperacaoIdempotente $runner, GatewayPagamento $gateway): void
    {
        $turno = Turno::find($this->turnoId);

        if ($turno === null || ! $this->deveLiberar($turno)) {
            return; // guard re-verificado no worker (espelho do CA-9 da 065)
        }

        try {
            $resultado = $runner->executar(
                $turno->id,
                TipoOperacaoPagamento::Liberacao,
                ['total_liberado' => $turno->total_contratante, 'motivo' => $this->motivo],
                fn () => $gateway->liberar($turno->id),
            );
        } catch (GatewayIndisponivel $e) {
            throw $e; // transiente: worker retenta com backoff
        } catch (LiberacaoFalhou $e) {
            $this->registrarFalha($turno, $e->getMessage());

            return; // fatal: registrado e alertado (CA-4); sem retry automático
        }

        // CA-3 — audit SÓ na primeira conclusão (redispatch não duplica a timeline).
        if (! AuditLog::where('action', 'pagamento.liberado')->where('target_id', $turno->id)->exists()) {
            AuditLog::create([
                'actor_id' => null, // operação do sistema (worker)
                'action' => 'pagamento.liberado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => [
                    'tipo_operacao' => TipoOperacaoPagamento::Liberacao->value,
                    'pagarme_charge_id' => $resultado->pagarmeChargeId,
                    'total_liberado' => $turno->total_contratante,
                    'motivo' => $this->motivo, // CA-6: 'no_show' quando vem do cron
                ],
            ]);
        }
    }

    /** Esgotou as tentativas (gateway indisponível): mesma visibilidade da falha fatal. */
    public function failed(?\Throwable $e): void
    {
        $turno = Turno::find($this->turnoId);

        if ($turno === null) {
            return;
        }

        // Liberação concluída em tentativa anterior → retry tardio não abre caso falso.
        $liberada = PagamentoOperacao::where('turno_id', $turno->id)
            ->where('tipo_operacao', TipoOperacaoPagamento::Liberacao)
            ->where('status', StatusOperacaoPagamento::Concluida)
            ->exists();

        if ($liberada) {
            return;
        }

        $this->registrarFalha($turno, $e?->getMessage() ?? 'gateway indisponível (tentativas esgotadas)');
    }

    /** Estados em que a pré-autorização DEVE ser liberada (disputa s/ pagamento é EPIC-005). */
    private function deveLiberar(Turno $turno): bool
    {
        return in_array($turno->status, [
            TurnoStatus::CanceladoPro,
            TurnoStatus::CanceladoEmp,
            TurnoStatus::NoShowPro,
        ], true);
    }

    /** CA-4 — audit `pagamento.liberacao_falhou` + caso na fila operacional do admin. */
    private function registrarFalha(Turno $turno, string $razao): void
    {
        PixFalha::registrarLiberacao($turno, $razao);

        AuditLog::create([
            'actor_id' => null,
            'action' => 'pagamento.liberacao_falhou',
            'target_type' => 'Turno',
            'target_id' => $turno->id,
            'payload' => ['motivo' => $razao, 'origem' => $this->motivo],
        ]);
    }
}
