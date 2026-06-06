<?php

// STORY-065 (CA-1..4, 6, 9) — listener do TurnoFinalizado + job de captura + Pix.
// CA-1: TurnoFinalizadoListener consome o evento e enfileira CapturarEPagarTurnoJob
//       (fila database — ADR-002), com idempotência captura:{turno_id} (STORY-056).
// CA-2: sucesso da captura → audit `pagamento.capturado` + evento PagamentoCapturado
//       (charge_id retornado pelo gateway, valor capturado, timestamp).
// CA-3: em sequência, transferirPix com a chave Pix do perfil (EPIC-001), idempotência
//       pix:{turno_id}. Chave é DADO SENSÍVEL — nunca persiste/loga em claro.
// CA-6: a resposta síncrona do Pix NÃO grava `pix.enviado` — fonte de verdade é o
//       webhook (HandlePixEnviadoTest).
// CA-9: turno fora de `finalizado` não dispara captura (cancelamento → STORY-066 libera).
// PDR-010: falha de Pix = UMA tentativa, sem retry automático → caso em `pix_falhas`.

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
use App\Events\TurnoFinalizado;
use App\Jobs\CapturarEPagarTurnoJob;
use App\Models\AuditLog;
use App\Models\PagamentoOperacao;
use App\Models\PixFalha;
use App\Models\ProfissionalProfile;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Queue;

uses(RefreshDatabase::class);

/**
 * Duble do gateway na fronteira da ACL (colaborador externo — mock com critério).
 * Lança opcionalmente por operação para exercitar os caminhos de exceção.
 */
function gatewayCapturaPixFake(?Throwable $lancaCaptura = null, ?Throwable $lancaPix = null): object
{
    $fake = new class($lancaCaptura, $lancaPix) implements GatewayPagamento
    {
        public int $capturas = 0;

        public int $pixes = 0;

        public array $argsPix = [];

        public function __construct(
            private readonly ?Throwable $lancaCaptura,
            private readonly ?Throwable $lancaPix,
        ) {}

        public function preAutorizar(string $turnoId, string $totalContratante, string $meioPagamentoToken): ResultadoOperacao
        {
            throw new BadMethodCallException;
        }

        public function capturar(string $turnoId): ResultadoOperacao
        {
            $this->capturas++;
            if ($this->lancaCaptura) {
                throw $this->lancaCaptura;
            }

            return new ResultadoOperacao(
                tipo: TipoOperacaoPagamento::Captura,
                status: StatusOperacaoPagamento::Concluida,
                pagarmeChargeId: 'ch_captura',
                raw: ['id' => 'ch_captura', 'status' => 'paid'],
            );
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
            $this->pixes++;
            $this->argsPix = compact('turnoId', 'valorProfissional', 'chavePix');
            if ($this->lancaPix) {
                throw $this->lancaPix;
            }

            return new ResultadoOperacao(
                tipo: TipoOperacaoPagamento::Pix,
                status: StatusOperacaoPagamento::Concluida,
                pagarmeTransferId: 'tr_pix',
                raw: ['id' => 'tr_pix', 'status' => 'paid'],
            );
        }
    };

    app()->instance(GatewayPagamento::class, $fake);

    return $fake;
}

/** Turno `finalizado` com perfil do profissional portando chave Pix (EPIC-001). */
function turnoFinalizadoComChavePix(string $chave = 'carlos@pix.me'): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create([
        'valor' => 200.00, 'taxa_turni' => 30.00, 'total_contratante' => 230.00,
    ]);

    ProfissionalProfile::factory()->create([
        'user_id' => $turno->profissional_id,
        'chave_pix_encrypted' => $chave,
    ]);

    return $turno;
}

function rodarJob(Turno|string $turno): void
{
    $id = $turno instanceof Turno ? $turno->id : $turno;
    (new CapturarEPagarTurnoJob($id))->handle(app(OperacaoIdempotente::class), app(GatewayPagamento::class));
}

// ─── CA-1 — listener consome TurnoFinalizado e enfileira o job ────────────────

test('CA-1: evento TurnoFinalizado enfileira CapturarEPagarTurnoJob na fila database', function () {
    Queue::fake();
    $turno = turnoFinalizadoComChavePix();

    event(new TurnoFinalizado($turno->id));

    Queue::assertPushed(CapturarEPagarTurnoJob::class, fn ($job) => $job->turnoId === $turno->id
        && $job->connection === 'database');
});

test('CA-1: job roda na fila database (ADR-002)', function () {
    expect((new CapturarEPagarTurnoJob('qualquer'))->connection)->toBe('database');
});

// ─── CA-2 — caminho feliz da captura ─────────────────────────────────────────

test('CA-2/CA-3: sucesso → captura + Pix em sequência, audit pagamento.capturado + evento PagamentoCapturado', function () {
    Event::fake([PagamentoCapturado::class]);
    $gateway = gatewayCapturaPixFake();
    $turno = turnoFinalizadoComChavePix();

    rodarJob($turno);

    expect($gateway->capturas)->toBe(1)->and($gateway->pixes)->toBe(1)
        // CA-3: Pix do VALOR INTEGRAL do profissional (não o total), com a chave do perfil.
        ->and($gateway->argsPix['valorProfissional'])->toBe('200.00')
        ->and($gateway->argsPix['chavePix'])->toBe('carlos@pix.me');

    $opCaptura = PagamentoOperacao::where('turno_id', $turno->id)
        ->where('tipo_operacao', TipoOperacaoPagamento::Captura)->firstOrFail();
    $opPix = PagamentoOperacao::where('turno_id', $turno->id)
        ->where('tipo_operacao', TipoOperacaoPagamento::Pix)->firstOrFail();
    expect($opCaptura->status)->toBe(StatusOperacaoPagamento::Concluida)
        ->and($opCaptura->pagarme_charge_id)->toBe('ch_captura')
        ->and($opPix->status)->toBe(StatusOperacaoPagamento::Concluida)
        ->and($opPix->pagarme_transfer_id)->toBe('tr_pix')
        // CA-3: a chave Pix NUNCA persiste em claro na trilha da operação (ADR-016 g).
        ->and(json_encode($opPix->request_payload))->not->toContain('carlos@pix.me');

    // CA-2: audit + evento com charge_id, valor capturado e timestamp.
    $audit = AuditLog::where('action', 'pagamento.capturado')->where('target_id', $turno->id)->firstOrFail();
    expect($audit->payload['pagarme_charge_id'])->toBe('ch_captura')
        ->and($audit->payload['valor_capturado'])->toBe('230.00');

    Event::assertDispatched(PagamentoCapturado::class, fn ($e) => $e->turnoId === $turno->id
        && $e->pagarmeChargeId === 'ch_captura'
        && $e->valorCapturado === '230.00'
        && $e->capturadoEm !== null);
});

test('CA-6: a resposta síncrona do Pix NÃO grava pix.enviado (fonte de verdade é o webhook)', function () {
    gatewayCapturaPixFake();
    $turno = turnoFinalizadoComChavePix();

    rodarJob($turno);

    expect(AuditLog::where('action', 'pix.enviado')->exists())->toBeFalse();
});

// ─── CA-9 — guard de estado ───────────────────────────────────────────────────

test('CA-9: turno fora de finalizado NÃO dispara captura', function (TurnoStatus $status) {
    $gateway = gatewayCapturaPixFake();
    $turno = Turno::factory()->status($status)->create();

    rodarJob($turno);

    expect($gateway->capturas)->toBe(0)->and($gateway->pixes)->toBe(0)
        ->and(PagamentoOperacao::count())->toBe(0);
})->with([
    'ativo' => TurnoStatus::Ativo,
    'cancelado pelo profissional' => TurnoStatus::CanceladoPro,
    'cancelado pelo contratante' => TurnoStatus::CanceladoEmp,
]);

test('turno inexistente: job retorna sem erro (defensivo)', function () {
    $gateway = gatewayCapturaPixFake();

    rodarJob('0197a000-0000-7000-8000-000000000000');

    expect($gateway->capturas)->toBe(0)->and(PagamentoOperacao::count())->toBe(0);
});

// ─── (b) caso inválido — perfil sem chave Pix ─────────────────────────────────

test('CA-3: perfil SEM chave Pix → captura ok, Pix não chamado, caso na fila do admin', function () {
    Event::fake([PagamentoCapturado::class]);
    $gateway = gatewayCapturaPixFake();
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    ProfissionalProfile::factory()->create(['user_id' => $turno->profissional_id]); // sem chave

    rodarJob($turno);

    expect($gateway->capturas)->toBe(1)->and($gateway->pixes)->toBe(0);

    $falha = PixFalha::where('turno_id', $turno->id)->firstOrFail();
    expect($falha->razao)->toContain('chave Pix')
        ->and($falha->resolvido_em)->toBeNull();
    expect(AuditLog::where('action', 'pix.falhou')->where('target_id', $turno->id)->exists())->toBeTrue();
});

// ─── (c) exceções esperadas ───────────────────────────────────────────────────

test('captura falha fatal (CapturaFalhou) → operação falhou + audit, SEM Pix e sem relançar', function () {
    Event::fake([PagamentoCapturado::class]);
    $gateway = gatewayCapturaPixFake(lancaCaptura: new CapturaFalhou('pré-autorização expirada'));
    $turno = turnoFinalizadoComChavePix();

    rodarJob($turno);

    $op = PagamentoOperacao::where('turno_id', $turno->id)
        ->where('tipo_operacao', TipoOperacaoPagamento::Captura)->firstOrFail();
    expect($op->status)->toBe(StatusOperacaoPagamento::Falhou)
        ->and($op->erro)->toContain('pré-autorização expirada')
        ->and($gateway->pixes)->toBe(0);

    Event::assertNotDispatched(PagamentoCapturado::class);
    expect(AuditLog::where('action', 'pagamento.captura_falhou')->where('target_id', $turno->id)->exists())->toBeTrue();
});

test('GatewayIndisponivel na captura relança (worker retenta com backoff)', function () {
    gatewayCapturaPixFake(lancaCaptura: new GatewayIndisponivel('timeout'));
    $turno = turnoFinalizadoComChavePix();

    expect(fn () => rodarJob($turno))->toThrow(GatewayIndisponivel::class);

    expect(AuditLog::where('action', 'pagamento.capturado')->exists())->toBeFalse();
});

test('PDR-010: Pix falha fatal (PixFalhou) → UMA tentativa, caso na fila com a razão do gateway', function () {
    Event::fake([PagamentoCapturado::class]);
    $gateway = gatewayCapturaPixFake(lancaPix: new PixFalhouException('invalid_pix_key — chave não encontrada'));
    $turno = turnoFinalizadoComChavePix();

    rodarJob($turno); // não relança: falha fatal registrada, sem retry automático

    expect($gateway->pixes)->toBe(1);
    Event::assertDispatched(PagamentoCapturado::class); // captura aconteceu antes

    $falha = PixFalha::where('turno_id', $turno->id)->firstOrFail();
    expect($falha->razao)->toContain('invalid_pix_key');
    expect(AuditLog::where('action', 'pix.falhou')->where('target_id', $turno->id)->exists())->toBeTrue();
});

test('GatewayIndisponivel no Pix relança e a retentativa NÃO duplica a captura (curto-circuito)', function () {
    Event::fake([PagamentoCapturado::class]);
    $gateway = gatewayCapturaPixFake(lancaPix: new GatewayIndisponivel('timeout'));
    $turno = turnoFinalizadoComChavePix();

    expect(fn () => rodarJob($turno))->toThrow(GatewayIndisponivel::class);

    // Worker retenta: captura reaproveitada (1 chamada), Pix tentado de novo.
    gatewayCapturaPixFake(); // troca o duble por um que sucede
    rodarJob($turno);

    expect($gateway->capturas)->toBe(1) // o 1º duble nunca recebeu 2ª captura
        ->and(PagamentoOperacao::where('turno_id', $turno->id)->count())->toBe(2);
    expect(PagamentoOperacao::where('turno_id', $turno->id)
        ->where('tipo_operacao', TipoOperacaoPagamento::Pix)
        ->value('status'))->toBe(StatusOperacaoPagamento::Concluida);
});

// ─── (d) bordas ───────────────────────────────────────────────────────────────

test('clique-duplo/redispatch: job 2x chama capturar e transferirPix UMA vez cada', function () {
    Event::fake([PagamentoCapturado::class]);
    $gateway = gatewayCapturaPixFake();
    $turno = turnoFinalizadoComChavePix();

    rodarJob($turno);
    rodarJob($turno);

    expect($gateway->capturas)->toBe(1)->and($gateway->pixes)->toBe(1)
        ->and(PagamentoOperacao::where('turno_id', $turno->id)->count())->toBe(2);
});

test('failed() com captura concluída e Pix pendente → caso na fila (dinheiro capturado, Pix não saiu)', function () {
    $turno = turnoFinalizadoComChavePix();
    gatewayCapturaPixFake(lancaPix: new GatewayIndisponivel('timeout'));
    try {
        rodarJob($turno);
    } catch (GatewayIndisponivel) {
        // esperado — simula a 1ª tentativa do worker
    }

    (new CapturarEPagarTurnoJob($turno->id))->failed(new GatewayIndisponivel('tentativas esgotadas'));

    $falha = PixFalha::where('turno_id', $turno->id)->firstOrFail();
    expect($falha->razao)->toContain('tentativas esgotadas');
    expect(AuditLog::where('action', 'pix.falhou')->where('target_id', $turno->id)->exists())->toBeTrue();
});

test('failed() SEM captura concluída → audit pagamento.captura_falhou (sem caso de Pix)', function () {
    $turno = turnoFinalizadoComChavePix();

    (new CapturarEPagarTurnoJob($turno->id))->failed(new GatewayIndisponivel('gateway fora'));

    expect(AuditLog::where('action', 'pagamento.captura_falhou')->where('target_id', $turno->id)->exists())->toBeTrue()
        ->and(PixFalha::count())->toBe(0);
});

test('failed() com turno inexistente não explode (defensivo)', function () {
    (new CapturarEPagarTurnoJob('0197a000-0000-7000-8000-000000000000'))->failed(null);

    expect(AuditLog::count())->toBe(0);
});
