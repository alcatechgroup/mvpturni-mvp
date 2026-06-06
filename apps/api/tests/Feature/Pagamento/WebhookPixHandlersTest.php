<?php

// STORY-065 (CA-4, CA-5, CA-6) — handlers dos eventos de domínio que NASCEM do webhook do
// gateway (fonte de verdade do estado do pagamento — CA-6; o fake emite com HMAC, STORY-056):
//  - PixEnviado  → audit `pix.enviado` (liga a timeline da 060 e o "Pix enviado em HH:MM"
//    do card de valor — CA-4). Idempotente: redelivery não duplica a linha da timeline.
//  - PixFalhou   → audit `pix.falhou` + caso em `pix_falhas` com a razão do gateway (CA-5);
//    se chega APÓS sucesso aparente, o alerta é criado/atualizado do mesmo jeito (CA-6).

use App\Events\Pagamento\PixEnviado;
use App\Events\Pagamento\PixFalhou;
use App\Models\AuditLog;
use App\Models\PixFalha;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

// ─── PixEnviado — (a) caminho feliz ──────────────────────────────────────────

test('CA-4/CA-6: webhook PixEnviado grava audit pix.enviado com transfer_id e valor', function () {
    $turno = Turno::factory()->create(['valor' => 200.00]);

    event(new PixEnviado($turno->id, 'evt_1', [
        'type' => 'transfer.paid',
        'data' => ['transfer_id' => 'tr_abc', 'amount' => 20000, 'external_reference' => $turno->id],
    ]));

    $audit = AuditLog::where('action', 'pix.enviado')->where('target_id', $turno->id)->firstOrFail();
    expect($audit->payload['pagarme_transfer_id'])->toBe('tr_abc')
        ->and($audit->payload['valor'])->toBe('200.00');
});

// ─── PixEnviado — (d) borda: redelivery não duplica ──────────────────────────

test('CA-6: PixEnviado redelivery (outro event_id) NÃO duplica o audit da timeline', function () {
    $turno = Turno::factory()->create();

    event(new PixEnviado($turno->id, 'evt_1', ['data' => ['transfer_id' => 'tr_abc']]));
    event(new PixEnviado($turno->id, 'evt_2', ['data' => ['transfer_id' => 'tr_abc']]));

    expect(AuditLog::where('action', 'pix.enviado')->where('target_id', $turno->id)->count())->toBe(1);
});

// ─── PixEnviado — (b) inválido: turno inexistente ────────────────────────────

test('PixEnviado com turno inexistente não explode nem audita (defensivo)', function () {
    event(new PixEnviado('0197a000-0000-7000-8000-000000000000', 'evt_x', []));

    expect(AuditLog::where('action', 'pix.enviado')->count())->toBe(0);
});

// ─── PixEnviado — (d) borda: Pix confirmado encerra caso aberto? NÃO ─────────

test('PixEnviado NÃO fecha caso aberto em pix_falhas (resolução é decisão humana — PDR-010)', function () {
    $turno = Turno::factory()->create();
    PixFalha::registrar($turno->id, 'invalid_pix_key — chave não encontrada');

    event(new PixEnviado($turno->id, 'evt_1', ['data' => ['transfer_id' => 'tr_abc']]));

    // O caso permanece aberto: foi o admin quem resolveu fora da plataforma, e o audit
    // trail precisa da nota humana (CA-8). O webhook tardio não decide por ele.
    expect(PixFalha::where('turno_id', $turno->id)->whereNull('resolvido_em')->exists())->toBeTrue();
});

// ─── PixFalhou — (a) caminho feliz (falha determinística do fake) ────────────

test('CA-5: webhook PixFalhou cria caso na fila com a razão do gateway + audit pix.falhou', function () {
    $turno = Turno::factory()->create();

    event(new PixFalhou($turno->id, 'evt_f1', [
        'type' => 'transfer.failed',
        'data' => [
            'transfer_id' => 'tr_fail',
            'reason' => 'invalid_pix_key',
            'message' => 'chave não encontrada na instituição de destino',
            'external_reference' => $turno->id,
        ],
    ]));

    $falha = PixFalha::where('turno_id', $turno->id)->firstOrFail();
    expect($falha->razao)->toBe('invalid_pix_key — chave não encontrada na instituição de destino')
        ->and($falha->resolvido_em)->toBeNull()
        ->and($falha->payload_gateway['transfer_id'])->toBe('tr_fail');

    expect(AuditLog::where('action', 'pix.falhou')->where('target_id', $turno->id)->exists())->toBeTrue();
});

// ─── PixFalhou — (d) borda: payload sem razão estruturada ────────────────────

test('PixFalhou sem reason/message usa razão genérica honesta (variabilidade do externo)', function () {
    $turno = Turno::factory()->create();

    event(new PixFalhou($turno->id, 'evt_f2', ['data' => ['transfer_id' => 'tr_x']]));

    $falha = PixFalha::where('turno_id', $turno->id)->firstOrFail();
    expect($falha->razao)->toBe('falha reportada pelo gateway (sem razão estruturada)');
});

// ─── PixFalhou — (c) exceção do processo: falha APÓS sucesso aparente (CA-6) ─

test('CA-6: PixFalhou após pix.enviado (sucesso aparente) cria o caso mesmo assim', function () {
    $turno = Turno::factory()->create();
    event(new PixEnviado($turno->id, 'evt_ok', ['data' => ['transfer_id' => 'tr_abc']]));

    event(new PixFalhou($turno->id, 'evt_f3', [
        'data' => ['reason' => 'transfer_reversed', 'message' => 'transferência devolvida'],
    ]));

    $falha = PixFalha::where('turno_id', $turno->id)->firstOrFail();
    expect($falha->razao)->toContain('transfer_reversed')
        ->and($falha->resolvido_em)->toBeNull();
});

// ─── PixFalhou — (d) borda: redelivery atualiza caso aberto, preserva resolvido ─

test('PixFalhou em caso já RESOLVIDO não reabre (resolução humana é final)', function () {
    $turno = Turno::factory()->create();
    $caso = PixFalha::registrar($turno->id, 'motivo antigo');
    $caso->update(['resolvido_em' => now(), 'nota_resolucao' => 'Pix manual feito']);

    event(new PixFalhou($turno->id, 'evt_f4', ['data' => ['reason' => 'novo_motivo', 'message' => 'x']]));

    $caso->refresh();
    expect($caso->resolvido_em)->not->toBeNull()
        ->and($caso->razao)->toBe('motivo antigo');
});

test('PixFalhou com turno inexistente não explode (defensivo)', function () {
    event(new PixFalhou('0197a000-0000-7000-8000-000000000000', 'evt_f5', []));

    expect(PixFalha::count())->toBe(0);
});
