<?php

// STORY-065 (CA-7) — MÉTRICA PRIMÁRIA verificada em CI: 20 turnos seedados percorrendo o
// ciclo completo `finalizado → captura → Pix → webhook` com o fake em modo success
// (Http::fake com os payloads do contract.md — mesmo shape que o pagarme-mock devolve;
// Http::preventStrayRequests prova 0 rede). Para CADA turno medimos a janela entre o
// instante do `finalizado` e o audit `pix.enviado` (confirmação do webhook — CA-6) e
// exigimos 100% dentro da promessa pública "Pix em ≤ 15 min" (PDR-017: demonstrada como
// SIMULAÇÃO — em homolog o fake confirma em ~30s via PAGARME_MOCK_PIX_SLA_SEGUNDOS;
// aqui o pipeline inteiro roda em milissegundos, provando que nada no NOSSO lado
// consome a janela). Resultado impresso e anexado às Notas da estória.

use App\Domain\Pagamento\GatewayPagamento;
use App\Domain\Pagamento\OperacaoIdempotente;
use App\Domain\Pagamento\Webhook\PagarmeWebhookValidator;
use App\Enums\StatusOperacaoPagamento;
use App\Enums\TipoOperacaoPagamento;
use App\Enums\TurnoStatus;
use App\Jobs\CapturarEPagarTurnoJob;
use App\Jobs\ProcessarWebhookPagarmeJob;
use App\Models\AuditLog;
use App\Models\PagamentoOperacao;
use App\Models\ProfissionalProfile;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;

uses(RefreshDatabase::class);

const JANELA_PROMESSA_MIN = 15; // promessa pública "Pix em ≤ 15 min" (PDR-017)

/** Entrega o webhook assinado do fake e o processa (o que o worker faria). */
function entregarWebhookMetrica(string $type, string $turnoId, array $data = []): void
{
    $payload = [
        'id' => 'evt_'.uniqid(),
        'type' => $type,
        'data' => array_merge(['external_reference' => $turnoId], $data),
    ];
    $raw = json_encode($payload);
    test()->call(
        'POST', '/api/webhooks/pagarme', [], [], [],
        ['CONTENT_TYPE' => 'application/json', 'HTTP_X_PAGARME_SIGNATURE' => hash_hmac('sha256', $raw, 'whsec_test')],
        $raw,
    )->assertOk();
    (new ProcessarWebhookPagarmeJob($payload['id']))->handle(app(PagarmeWebhookValidator::class));
}

test('CA-7: 20 turnos seedados — 100% completam finalizado → Pix enviado dentro da promessa', function () {
    config()->set('services.pagarme.base_url', 'http://pagarme-mock:8080');
    config()->set('services.pagarme.webhook_secret', 'whsec_test');
    Http::preventStrayRequests();

    // Fake em modo success: respostas com o shape do contract.md (idênticas às do
    // pagarme-mock).
    Http::fake([
        '*/orders' => Http::response(['id' => 'or_m', 'status' => 'pending',
            'charges' => [['id' => 'ch_m', 'status' => 'authorized']]]),
        '*/charges/*/capture' => Http::response(['id' => 'ch_m', 'status' => 'paid']),
        '*/transfers' => Http::response(['id' => 'tr_m', 'status' => 'processing']),
    ]);

    $turnos = Turno::factory()->count(20)->status(TurnoStatus::Finalizado)->create([
        'valor' => 200.00, 'taxa_turni' => 30.00, 'total_contratante' => 230.00,
    ]);
    $runner = app(OperacaoIdempotente::class);
    $gateway = app(GatewayPagamento::class);
    foreach ($turnos as $t) {
        ProfissionalProfile::factory()->create([
            'user_id' => $t->profissional_id,
            'chave_pix_encrypted' => 'metrica@pix.turni.local',
        ]);
        // Pré-autorização da STORY-058 (aprovação da candidatura) — a captura precisa
        // da charge; acontece FORA da janela medida (a promessa conta do finalizado).
        $runner->executar($t->id, TipoOperacaoPagamento::PreAutorizacao,
            ['total_contratante' => '230.00'],
            fn () => $gateway->preAutorizar($t->id, '230.00', 'tok_metrica'));
    }

    $janelas = [];
    foreach ($turnos as $t) {
        $finalizadoEm = microtime(true); // instante do TurnoFinalizado (064)

        // Pipeline real da 065: job (captura + Pix via adapter) + webhook de confirmação.
        (new CapturarEPagarTurnoJob($t->id))->handle(app(OperacaoIdempotente::class), app(GatewayPagamento::class));
        entregarWebhookMetrica('transfer.paid', $t->id, ['transfer_id' => 'tr_m', 'amount' => 20000]);

        $confirmadoEm = microtime(true);
        $janelas[$t->id] = $confirmadoEm - $finalizadoEm;
    }

    // 100% completaram: audit pix.enviado (fonte de verdade) + operações concluídas.
    $completos = 0;
    foreach ($turnos as $t) {
        $enviou = AuditLog::where('action', 'pix.enviado')->where('target_id', $t->id)->exists();
        $operacoes = PagamentoOperacao::where('turno_id', $t->id)
            ->where('status', StatusOperacaoPagamento::Concluida)->count();
        if ($enviou && $operacoes === 3) { // pré-auth + captura + pix
            $completos++;
        }
    }

    $maxMs = (int) round(max($janelas) * 1000);
    $mediaMs = (int) round(array_sum($janelas) / count($janelas) * 1000);
    $dentroDaJanela = count(array_filter($janelas, fn ($s) => $s <= JANELA_PROMESSA_MIN * 60));

    // Resultado anexável à estória (CA-7).
    fwrite(STDERR, sprintf(
        "\n[CA-7] 20 turnos: %d/20 ciclo completo (pix.enviado + 3 operações concluídas); ".
        '%d/20 dentro da janela de %d min; pipeline max %d ms, média %d ms '.
        "(simulação — SLA real do fake em homolog: ~30s)\n",
        $completos, $dentroDaJanela, JANELA_PROMESSA_MIN, $maxMs, $mediaMs,
    ));

    expect($completos)->toBe(20)        // 100% do ciclo completo (CA-7)
        ->and($dentroDaJanela)->toBe(20); // 100% dentro da promessa de 15 min
});
