<?php

// STORY-066 (CA-2/CA-3/CA-4/CA-6) — LiberarPreAutorizacaoJob: libera a pré-autorização via
// ACL (fake genérico — PDR-017) com idempotência liberacao:{turno_id} (STORY-056/ADR-016).
// Sucesso → audit `pagamento.liberado` (com motivo cancelamento|no_show) UMA vez.
// Falha fatal (LiberacaoFalhou) → audit `pagamento.liberacao_falhou` + caso tipo `liberacao`
// na fila operacional do admin (mesma fila da STORY-065 — generalizada).
// GatewayIndisponivel → retry do worker; tentativas esgotadas → mesmo desfecho de falha.

use App\Domain\Pagamento\Exceptions\GatewayIndisponivel;
use App\Domain\Pagamento\Exceptions\LiberacaoFalhou;
use App\Domain\Pagamento\GatewayPagamento;
use App\Domain\Pagamento\OperacaoIdempotente;
use App\Domain\Pagamento\ResultadoOperacao;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Enums\TurnoStatus;
use App\Jobs\LiberarPreAutorizacaoJob;
use App\Models\AuditLog;
use App\Models\PagamentoOperacao;
use App\Models\PixFalha;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/** Duble do gateway na fronteira da ACL — só `liberar` é esperado neste job. */
function gatewayLiberacaoFake(?Throwable $lanca = null): object
{
    $fake = new class($lanca) implements GatewayPagamento
    {
        public int $liberacoes = 0;

        public function __construct(private readonly ?Throwable $lanca) {}

        public function preAutorizar(string $turnoId, string $totalContratante, string $meioPagamentoToken): ResultadoOperacao
        {
            throw new BadMethodCallException;
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
            $this->liberacoes++;
            if ($this->lanca) {
                throw $this->lanca;
            }

            return new ResultadoOperacao(
                tipo: TipoOperacaoPagamento::Liberacao,
                status: StatusOperacaoPagamento::Concluida,
                pagarmeChargeId: 'ch_liberada',
                raw: ['id' => 'ch_liberada', 'status' => 'canceled'],
            );
        }

        public function transferirPix(string $turnoId, string $valorProfissional, string $chavePix): ResultadoOperacao
        {
            throw new BadMethodCallException;
        }
    };

    app()->instance(GatewayPagamento::class, $fake);

    return $fake;
}

function turnoCancelado(TurnoStatus $status = TurnoStatus::CanceladoPro): Turno
{
    return Turno::factory()->status($status)->create([
        'valor' => 200.00, 'taxa_turni' => 30.00, 'total_contratante' => 230.00,
    ]);
}

function rodarLiberacao(Turno|string $turno, string $motivo = 'cancelamento'): void
{
    $id = $turno instanceof Turno ? $turno->id : $turno;
    (new LiberarPreAutorizacaoJob($id, $motivo))->handle(app(OperacaoIdempotente::class), app(GatewayPagamento::class));
}

// ─── Caminho feliz ────────────────────────────────────────────────────────────

test('sucesso → liberar chamado, operação liberacao concluida e audit pagamento.liberado com motivo', function () {
    $gateway = gatewayLiberacaoFake();
    $turno = turnoCancelado();

    rodarLiberacao($turno);

    expect($gateway->liberacoes)->toBe(1);

    $op = PagamentoOperacao::where('turno_id', $turno->id)
        ->where('tipo_operacao', TipoOperacaoPagamento::Liberacao)->first();
    expect($op)->not->toBeNull()
        ->and($op->status)->toBe(StatusOperacaoPagamento::Concluida)
        ->and($op->idempotencia_chave)->toBe("liberacao:{$turno->id}");

    $log = AuditLog::where('action', 'pagamento.liberado')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->actor_id)->toBeNull() // operação do sistema
        ->and($log->payload['motivo'])->toBe('cancelamento')
        ->and($log->payload['total_liberado'])->toBe('230.00');
});

test('CA-6: no-show libera igual, com motivo no_show no audit', function () {
    gatewayLiberacaoFake();
    $turno = turnoCancelado(TurnoStatus::NoShowPro);

    rodarLiberacao($turno, 'no_show');

    expect(AuditLog::where('action', 'pagamento.liberado')->where('target_id', $turno->id)->first()?->payload['motivo'])
        ->toBe('no_show');
});

test('idempotência: redispatch não chama o gateway de novo nem duplica o audit (curto-circuito)', function () {
    $gateway = gatewayLiberacaoFake();
    $turno = turnoCancelado();

    rodarLiberacao($turno);
    rodarLiberacao($turno);

    expect($gateway->liberacoes)->toBe(1)
        ->and(AuditLog::where('action', 'pagamento.liberado')->where('target_id', $turno->id)->count())->toBe(1);
});

// ─── Guard de estado (espelho do CA-9 da 065) ────────────────────────────────

dataset('estados_sem_liberacao', [
    'confirmado (cancelamento não aconteceu)' => [TurnoStatus::Confirmado],
    'ativo' => [TurnoStatus::Ativo],
    'finalizado (caminho de captura, não de liberação)' => [TurnoStatus::Finalizado],
]);

test('turno fora de estado liberável → no-op (gateway não é chamado)', function (TurnoStatus $estado) {
    $gateway = gatewayLiberacaoFake();
    $turno = Turno::factory()->status($estado)->create();

    rodarLiberacao($turno);

    expect($gateway->liberacoes)->toBe(0);
})->with('estados_sem_liberacao');

test('turno inexistente → no-op silencioso', function () {
    $gateway = gatewayLiberacaoFake();

    rodarLiberacao('00000000-0000-7000-8000-000000000000');

    expect($gateway->liberacoes)->toBe(0);
});

// ─── CA-4 — falha fatal: audit + fila operacional do admin ──────────────────

test('LiberacaoFalhou → audit pagamento.liberacao_falhou com motivo + caso tipo liberacao na fila do admin', function () {
    gatewayLiberacaoFake(new LiberacaoFalhou('release_failed — pré-autorização não encontrada no gateway'));
    $turno = turnoCancelado();

    rodarLiberacao($turno);

    $log = AuditLog::where('action', 'pagamento.liberacao_falhou')
        ->where('target_type', 'Turno')->where('target_id', $turno->id)->first();
    expect($log)->not->toBeNull()
        ->and($log->payload['motivo'])->toContain('release_failed');

    $caso = PixFalha::where('turno_id', $turno->id)->first();
    expect($caso)->not->toBeNull()
        ->and($caso->tipo)->toBe('liberacao')
        ->and($caso->razao)->toContain('release_failed')
        // o admin trata a LIBERAÇÃO: o valor do caso é o total reservado do contratante
        ->and($caso->valor)->toBe('230.00')
        // liberação não tem chave Pix (o tratamento é no gateway, não transferência)
        ->and($caso->chave_pix)->toBeNull()
        ->and($caso->resolvido_em)->toBeNull();

    // nenhum `pagamento.liberado` em falha
    expect(AuditLog::where('action', 'pagamento.liberado')->where('target_id', $turno->id)->exists())->toBeFalse();
});

test('GatewayIndisponivel → relança para retry do worker (sem audit de falha ainda)', function () {
    gatewayLiberacaoFake(new GatewayIndisponivel('Pagar.me inacessível: timeout'));
    $turno = turnoCancelado();

    expect(fn () => rodarLiberacao($turno))->toThrow(GatewayIndisponivel::class);

    expect(AuditLog::where('action', 'pagamento.liberacao_falhou')->where('target_id', $turno->id)->exists())->toBeFalse()
        ->and(PixFalha::where('turno_id', $turno->id)->exists())->toBeFalse();
});

test('failed() (tentativas esgotadas) → registra liberacao_falhou + caso na fila', function () {
    $turno = turnoCancelado();

    (new LiberarPreAutorizacaoJob($turno->id, 'cancelamento'))
        ->failed(new GatewayIndisponivel('gateway indisponível (tentativas esgotadas)'));

    expect(AuditLog::where('action', 'pagamento.liberacao_falhou')->where('target_id', $turno->id)->exists())->toBeTrue()
        ->and(PixFalha::where('turno_id', $turno->id)->first()?->tipo)->toBe('liberacao');
});

test('failed() após liberação concluída (retry tardio) → NÃO abre caso (dinheiro já liberado)', function () {
    gatewayLiberacaoFake();
    $turno = turnoCancelado();
    rodarLiberacao($turno); // conclui

    (new LiberarPreAutorizacaoJob($turno->id, 'cancelamento'))
        ->failed(new GatewayIndisponivel('timeout tardio'));

    expect(PixFalha::where('turno_id', $turno->id)->exists())->toBeFalse()
        ->and(AuditLog::where('action', 'pagamento.liberacao_falhou')->where('target_id', $turno->id)->exists())->toBeFalse();
});

test('failed() com turno inexistente → no-op silencioso', function () {
    (new LiberarPreAutorizacaoJob('00000000-0000-7000-8000-000000000000', 'cancelamento'))
        ->failed(new GatewayIndisponivel('timeout'));

    expect(PixFalha::count())->toBe(0)
        ->and(AuditLog::where('action', 'pagamento.liberacao_falhou')->exists())->toBeFalse();
});

test('job roda na fila database (ADR-002)', function () {
    expect((new LiberarPreAutorizacaoJob('qualquer', 'cancelamento'))->connection)->toBe('database');
});
