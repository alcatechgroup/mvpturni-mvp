<?php

// STORY-068 (F-NB-2) / ADR-008 §f — propagação de `request_id` api→fila→worker.
// Middleware lê o X-Cloud-Trace-Context que o Cloud Run injeta (reaproveita o trace
// do GCP; fallback ULID), põe o id no Context (Laravel) — que (a) anexa o campo em
// TODA linha de log da requisição (extra.request_id no JSON) e (b) desidrata o
// contexto no payload de jobs enfileirados, re-hidratando no worker: a cadeia
// pré-autorização → captura → Pix fica rastreável pelo MESMO request_id.

use App\Domain\Pagamento\GatewayPagamento;
use App\Domain\Pagamento\ResultadoOperacao;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Jobs\PreAutorizarTurnoJob;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Context;
use Illuminate\Support\Facades\Log;
use Monolog\Handler\TestHandler;

uses(RefreshDatabase::class);

// ─── (a) middleware — request_id nasce na borda ───────────────────────────────

test('reusa o trace do Cloud Run como request_id e devolve X-Request-Id', function () {
    $res = $this->get('/health', ['X-Cloud-Trace-Context' => 'abc123def456/789;o=1']);

    $res->assertOk();
    expect($res->headers->get('X-Request-Id'))->toBe('abc123def456')
        ->and(Context::get('request_id'))->toBe('abc123def456');
});

test('sem trace do Cloud Run gera ULID como request_id (fallback do ADR-008 f)', function () {
    $res = $this->get('/health');

    $res->assertOk();
    $rid = $res->headers->get('X-Request-Id');
    expect($rid)->toHaveLength(26) // ULID canônico
        ->and(Context::get('request_id'))->toBe($rid);
});

test('toda linha de log da requisição carrega o request_id (extra do JSON)', function () {
    $handler = new TestHandler;
    Log::getLogger()->pushHandler($handler);

    $this->get('/health', ['X-Cloud-Trace-Context' => 'trace-na-borda/1;o=1']);
    Log::info('evento.qualquer', ['campo' => 'x']);

    $registro = collect($handler->getRecords())->first(fn ($r) => $r->message === 'evento.qualquer');
    expect($registro)->not->toBeNull()
        ->and($registro->extra['request_id'] ?? null)->toBe('trace-na-borda');
});

// ─── (b) fila — operação financeira no worker loga o MESMO request_id ─────────

test('job financeiro processado pelo worker loga com o request_id da requisição de origem', function () {
    // Gateway dublê na fronteira da ACL (espelho do PreAutorizarTurnoJobTest).
    app()->instance(GatewayPagamento::class, new class implements GatewayPagamento
    {
        public function preAutorizar(string $turnoId, string $totalContratante, string $meioPagamentoToken): ResultadoOperacao
        {
            return new ResultadoOperacao(
                tipo: TipoOperacaoPagamento::PreAutorizacao,
                status: StatusOperacaoPagamento::Concluida,
                pagarmeOrderId: 'or_ctx',
                pagarmeChargeId: 'ch_ctx',
                raw: ['id' => 'or_ctx'],
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
    });

    $handler = new TestHandler;
    Log::getLogger()->pushHandler($handler);
    $turno = Turno::factory()->create();

    // "api": requisição com trace do Cloud Run enfileira o job na fila REAL (database).
    config(['queue.default' => 'database']);
    Context::add('request_id', 'rid-da-requisicao');
    PreAutorizarTurnoJob::dispatch($turno->id);

    // "worker": outro processo — o contexto da requisição não existe mais.
    Context::flush();
    expect(Context::get('request_id'))->toBeNull();
    Artisan::call('queue:work', ['--once' => true, '--queue' => 'default']);

    $registro = collect($handler->getRecords())
        ->first(fn ($r) => $r->message === 'pagamento.operacao_concluida');
    expect($registro)->not->toBeNull()
        ->and($registro->extra['request_id'] ?? null)->toBe('rid-da-requisicao')
        ->and($registro->context['operacao'] ?? null)->toBe('pre_autorizacao');
});
