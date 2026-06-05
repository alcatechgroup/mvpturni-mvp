<?php

// STORY-058 (CA-6, CA-7) — job assíncrono de pré-autorização (worker, fila database — ADR-002).
// Sucesso → evento de domínio PagamentoPreAutorizado + audit log `pagamento.pre_autorizado`.
// Falha fatal (PreAutorizacaoNegada) → PagamentoPreAutorizacaoFalhou + audit
// `pagamento.pre_autorizacao_falhou` + operação `falhou` (sem retry automático — fora de escopo).
// Falha transiente (GatewayIndisponivel) → relança para o worker retentar (backoff).
// Idempotência (STORY-056): retry/duplicata reaproveita a operação concluída sem 2ª chamada.

use App\Domain\Pagamento\Exceptions\GatewayIndisponivel;
use App\Domain\Pagamento\Exceptions\PreAutorizacaoNegada;
use App\Domain\Pagamento\GatewayPagamento;
use App\Domain\Pagamento\ResultadoOperacao;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Events\Pagamento\PagamentoPreAutorizacaoFalhou;
use App\Events\Pagamento\PagamentoPreAutorizado;
use App\Jobs\PreAutorizarTurnoJob;
use App\Models\AuditLog;
use App\Models\PagamentoOperacao;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;

uses(RefreshDatabase::class);

/** Duble do gateway na fronteira da ACL (colaborador externo — mock com critério). */
function gatewayPreAuthFake(?\Throwable $lanca = null): object
{
    $fake = new class($lanca) implements GatewayPagamento
    {
        public int $chamadas = 0;

        public array $args = [];

        public function __construct(private readonly ?\Throwable $lanca) {}

        public function preAutorizar(string $turnoId, string $totalContratante, string $meioPagamentoToken): ResultadoOperacao
        {
            $this->chamadas++;
            $this->args = compact('turnoId', 'totalContratante', 'meioPagamentoToken');
            if ($this->lanca) {
                throw $this->lanca;
            }

            return new ResultadoOperacao(
                tipo: TipoOperacaoPagamento::PreAutorizacao,
                status: StatusOperacaoPagamento::Concluida,
                pagarmeOrderId: 'or_job',
                pagarmeChargeId: 'ch_job',
                raw: ['id' => 'or_job', 'charges' => [['id' => 'ch_job']]],
            );
        }

        public function capturar(string $turnoId): ResultadoOperacao
        {
            throw new BadMethodCallException;
        }

        public function capturarParcial(string $turnoId, string $valorRevisado): ResultadoOperacao
        {
            throw new BadMethodCallException;
        }

        public function liberar(string $turnoId): ResultadoOperacao
        {
            throw new BadMethodCallException;
        }

        public function transferirPix(string $turnoId, string $valorProfissional, string $chavePix): ResultadoOperacao
        {
            throw new BadMethodCallException;
        }
    };

    app()->instance(GatewayPagamento::class, $fake);

    return $fake;
}

// ─── (a) caminho feliz ────────────────────────────────────────────────────────

test('CA-6: sucesso → operação concluída + evento PagamentoPreAutorizado + audit log', function () {
    Event::fake([PagamentoPreAutorizado::class]);
    $gateway = gatewayPreAuthFake();
    $turno = Turno::factory()->create(['total_contratante' => 230.00, 'valor' => 200.00, 'taxa_turni' => 30.00]);

    (new PreAutorizarTurnoJob($turno->id))->handle(app(\App\Domain\Pagamento\OperacaoIdempotente::class), app(GatewayPagamento::class));

    expect($gateway->chamadas)->toBe(1)
        ->and($gateway->args['totalContratante'])->toBe('230.00');

    $op = PagamentoOperacao::where('turno_id', $turno->id)->firstOrFail();
    expect($op->status)->toBe(StatusOperacaoPagamento::Concluida)
        ->and($op->tipo_operacao)->toBe(TipoOperacaoPagamento::PreAutorizacao)
        ->and($op->pagarme_charge_id)->toBe('ch_job');

    Event::assertDispatched(PagamentoPreAutorizado::class, fn ($e) => $e->turnoId === $turno->id);

    $audit = AuditLog::where('action', 'pagamento.pre_autorizado')->first();
    expect($audit)->not->toBeNull()
        ->and($audit->target_id)->toBe($turno->id);
});

// ─── (d) borda — idempotência no retry/duplicata ─────────────────────────────

test('CA-5/CA-6: job executado duas vezes chama o provedor UMA vez (curto-circuito)', function () {
    Event::fake([PagamentoPreAutorizado::class]);
    $gateway = gatewayPreAuthFake();
    $turno = Turno::factory()->create();

    $job = new PreAutorizarTurnoJob($turno->id);
    $job->handle(app(\App\Domain\Pagamento\OperacaoIdempotente::class), app(GatewayPagamento::class));
    $job->handle(app(\App\Domain\Pagamento\OperacaoIdempotente::class), app(GatewayPagamento::class));

    expect($gateway->chamadas)->toBe(1)
        ->and(PagamentoOperacao::where('turno_id', $turno->id)->count())->toBe(1);
});

// ─── (b/c) falha fatal de negócio ────────────────────────────────────────────

test('CA-6: PreAutorizacaoNegada → operação falhou + evento de falha + audit; NÃO relança', function () {
    Event::fake([PagamentoPreAutorizacaoFalhou::class]);
    gatewayPreAuthFake(new PreAutorizacaoNegada('cartão recusado'));
    $turno = Turno::factory()->create();

    // Falha fatal é registrada e alerta o admin — sem retry automático (fora de escopo da estória).
    (new PreAutorizarTurnoJob($turno->id))->handle(app(\App\Domain\Pagamento\OperacaoIdempotente::class), app(GatewayPagamento::class));

    $op = PagamentoOperacao::where('turno_id', $turno->id)->firstOrFail();
    expect($op->status)->toBe(StatusOperacaoPagamento::Falhou)
        ->and($op->erro)->toContain('cartão recusado');

    Event::assertDispatched(PagamentoPreAutorizacaoFalhou::class, fn ($e) => $e->turnoId === $turno->id);
    expect(AuditLog::where('action', 'pagamento.pre_autorizacao_falhou')->exists())->toBeTrue();
});

// ─── (c) falha transiente ─────────────────────────────────────────────────────

test('CA-6: GatewayIndisponivel relança (worker retenta com backoff)', function () {
    Event::fake([PagamentoPreAutorizado::class, PagamentoPreAutorizacaoFalhou::class]);
    gatewayPreAuthFake(new GatewayIndisponivel('timeout'));
    $turno = Turno::factory()->create();

    expect(fn () => (new PreAutorizarTurnoJob($turno->id))
        ->handle(app(\App\Domain\Pagamento\OperacaoIdempotente::class), app(GatewayPagamento::class)))
        ->toThrow(GatewayIndisponivel::class);

    // Transiente não emite evento de desfecho — o desfecho ainda não aconteceu.
    Event::assertNotDispatched(PagamentoPreAutorizado::class);
    Event::assertNotDispatched(PagamentoPreAutorizacaoFalhou::class);
});

// ─── (d) bordas ───────────────────────────────────────────────────────────────

test('turno inexistente: job retorna sem erro (defensivo)', function () {
    $gateway = gatewayPreAuthFake();

    (new PreAutorizarTurnoJob('0197a000-0000-7000-8000-000000000000'))
        ->handle(app(\App\Domain\Pagamento\OperacaoIdempotente::class), app(GatewayPagamento::class));

    expect($gateway->chamadas)->toBe(0)->and(PagamentoOperacao::count())->toBe(0);
});

test('job roda na fila database (ADR-002)', function () {
    $job = new PreAutorizarTurnoJob('qualquer');

    expect($job->connection)->toBe('database');
});
