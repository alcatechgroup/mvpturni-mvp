<?php

// STORY-067 — listeners dos 8 eventos do turno → tabela `notificacoes` (CA-1/2/3).
// Cobre: destinatário por tipo (profissional/contratante/outro lado/ambos), payload do contrato
// da SCREEN-STORY-067 §2 (turno_id, vaga_funcao, estabelecimento_nome apelido>nome>name,
// turno_data_inicio pt-BR 24h, valor "1.234,56", link_turno), idempotência `{tipo}:{turno_id}`
// (e `:{geracao_pin_id}` para checkin/checkout — re-geração de PIN RE-notifica) e o caso
// defensivo (turno desconhecido não derruba o worker). Eventos despachados de verdade (sem
// Event::fake) para exercitar o registro do AppServiceProvider — mesmo padrão da STORY-053.

use App\Enums\NotificacaoTipo;
use App\Enums\TurnoStatus;
use App\Events\CheckinSolicitado;
use App\Events\CheckoutSolicitado;
use App\Events\Pagamento\PixEnviado;
use App\Events\TurnoCancelado;
use App\Events\TurnoCriado;
use App\Events\TurnoFinalizado;
use App\Events\TurnoIniciado;
use App\Events\TurnoNoShow;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\Notificacao;
use App\Models\Turno;
use App\Models\Vaga;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

/** Turno coerente p/ os payloads: função nomeada, contratante com perfil, datas BRT fixas. */
function turnoNotificavel(string $funcao = 'Garçom', TurnoStatus $status = TurnoStatus::Confirmado): Turno
{
    $vaga = Vaga::factory()->create([
        'funcao_id' => Funcao::factory()->create(['nome' => $funcao])->id,
        'data_inicio' => Carbon::parse('2026-07-01 18:00', 'America/Sao_Paulo'),
        'data_fim' => Carbon::parse('2026-07-01 23:00', 'America/Sao_Paulo'),
    ]);

    $turno = Turno::factory()->status($status)->create([
        'vaga_id' => $vaga->id,
        'contratante_id' => $vaga->contratante_id,
        'estabelecimento_id' => $vaga->contratante_id,
        'valor' => 200.00,
        'taxa_turni' => 30.00,            // 15% (PDR-004) — constraint turnos_total_consistente
        'total_contratante' => 230.00,
        'data_inicio' => $vaga->data_inicio,
        'data_fim' => $vaga->data_fim,
    ]);

    ContratanteProfile::create([
        'user_id' => $turno->contratante_id,
        'nome_estabelecimento' => 'Restaurante Vela Ltda',
        'apelido_estabelecimento' => 'Vela Bar',
    ]);

    return $turno;
}

// ── turno_confirmado (TurnoCriado → profissional) ─────────────────────────────

it('TurnoCriado notifica o profissional com turno_confirmado e payload completo (CA-1/CA-2)', function () {
    $turno = turnoNotificavel('Garçom');

    TurnoCriado::dispatch($turno->id);

    $n = Notificacao::where('tipo', NotificacaoTipo::TurnoConfirmado)->first();
    expect($n)->not->toBeNull()
        ->and($n->destinatario_id)->toBe($turno->profissional_id)
        ->and($n->vaga_id)->toBe($turno->vaga_id)
        ->and($n->candidatura_id)->toBe($turno->candidatura_id)
        ->and($n->idempotency_key)->toBe("turno_confirmado:{$turno->id}")
        ->and($n->payload['turno_id'])->toBe($turno->id)
        ->and($n->payload['vaga_funcao'])->toBe('Garçom')
        // apelido > nome > name (regra STORY-049/059)
        ->and($n->payload['estabelecimento_nome'])->toBe('Vela Bar')
        // pt-BR 24h (DDR-002): dd/mm/aaaa HH:mm, nunca AM/PM
        ->and($n->payload['turno_data_inicio'])->toBe('01/07/2026 18:00')
        ->and($n->payload['valor'])->toBe('200,00')
        ->and($n->payload['link_turno'])->toContain("/turnos/{$turno->id}");
});

it('TurnoCriado é idempotente — repetir o evento não duplica (CA-3)', function () {
    $turno = turnoNotificavel();

    TurnoCriado::dispatch($turno->id);
    TurnoCriado::dispatch($turno->id);

    expect(Notificacao::where('tipo', NotificacaoTipo::TurnoConfirmado)->count())->toBe(1);
});

// ── checkin_solicitado (CheckinSolicitado → contratante, chave por geração de PIN) ──

it('CheckinSolicitado notifica o contratante com o nome do profissional (CA-1)', function () {
    $turno = turnoNotificavel('Cozinheiro', TurnoStatus::AguardandoCheckin);
    $geracao = (string) Str::uuid7();

    CheckinSolicitado::dispatch($turno->id, $geracao);

    $n = Notificacao::where('tipo', NotificacaoTipo::CheckinSolicitado)->first();
    expect($n)->not->toBeNull()
        ->and($n->destinatario_id)->toBe($turno->contratante_id)
        ->and($n->idempotency_key)->toBe("checkin_solicitado:{$turno->id}:{$geracao}")
        ->and($n->payload['profissional_nome'])->toBe($turno->profissional->name)
        ->and($n->payload['vaga_funcao'])->toBe('Cozinheiro');
});

it('re-gerar o PIN de check-in RE-notifica; o mesmo evento repetido não (CA-3)', function () {
    $turno = turnoNotificavel(status: TurnoStatus::AguardandoCheckin);
    $g1 = (string) Str::uuid7();
    $g2 = (string) Str::uuid7();

    CheckinSolicitado::dispatch($turno->id, $g1);
    CheckinSolicitado::dispatch($turno->id, $g1); // redelivery: deduplica
    CheckinSolicitado::dispatch($turno->id, $g2); // PIN novo: notifica de novo

    expect(Notificacao::where('tipo', NotificacaoTipo::CheckinSolicitado)->count())->toBe(2);
});

// ── turno_ativo (TurnoIniciado → profissional) ────────────────────────────────

it('TurnoIniciado notifica o profissional com turno_ativo, idempotente (CA-1/CA-3)', function () {
    $turno = turnoNotificavel(status: TurnoStatus::Ativo);

    TurnoIniciado::dispatch($turno->id);
    TurnoIniciado::dispatch($turno->id);

    $n = Notificacao::where('tipo', NotificacaoTipo::TurnoAtivo)->get();
    expect($n)->toHaveCount(1)
        ->and($n->first()->destinatario_id)->toBe($turno->profissional_id)
        ->and($n->first()->idempotency_key)->toBe("turno_ativo:{$turno->id}");
});

// ── checkout_solicitado (CheckoutSolicitado → contratante) ────────────────────

it('CheckoutSolicitado notifica o contratante; chave por geração de PIN (CA-1/CA-3)', function () {
    $turno = turnoNotificavel(status: TurnoStatus::AguardandoCheckout);
    $g1 = (string) Str::uuid7();
    $g2 = (string) Str::uuid7();

    CheckoutSolicitado::dispatch($turno->id, $g1);
    CheckoutSolicitado::dispatch($turno->id, $g1);
    CheckoutSolicitado::dispatch($turno->id, $g2);

    $ns = Notificacao::where('tipo', NotificacaoTipo::CheckoutSolicitado)->get();
    expect($ns)->toHaveCount(2)
        ->and($ns->first()->destinatario_id)->toBe($turno->contratante_id)
        ->and($ns->first()->payload['profissional_nome'])->toBe($turno->profissional->name);
});

// ── turno_finalizado (TurnoFinalizado → profissional) ─────────────────────────

it('TurnoFinalizado notifica o profissional com o valor, idempotente (CA-1/CA-3)', function () {
    $turno = turnoNotificavel(status: TurnoStatus::Finalizado);

    TurnoFinalizado::dispatch($turno->id);
    TurnoFinalizado::dispatch($turno->id);

    $ns = Notificacao::where('tipo', NotificacaoTipo::TurnoFinalizado)->get();
    expect($ns)->toHaveCount(1)
        ->and($ns->first()->destinatario_id)->toBe($turno->profissional_id)
        ->and($ns->first()->payload['valor'])->toBe('200,00');
});

// ── pix_enviado (PixEnviado → profissional) ───────────────────────────────────

it('PixEnviado notifica o profissional; redelivery do webhook não duplica (CA-1/CA-3)', function () {
    $turno = turnoNotificavel(status: TurnoStatus::Finalizado);

    PixEnviado::dispatch($turno->id, 'evt_1', []);
    PixEnviado::dispatch($turno->id, 'evt_2', []); // redelivery: event_id novo, mesmo Pix

    $ns = Notificacao::where('tipo', NotificacaoTipo::PixEnviado)->get();
    expect($ns)->toHaveCount(1)
        ->and($ns->first()->destinatario_id)->toBe($turno->profissional_id)
        ->and($ns->first()->idempotency_key)->toBe("pix_enviado:{$turno->id}")
        ->and($ns->first()->payload['valor'])->toBe('200,00');
});

it('PixEnviado com turno desconhecido não cria notificação nem derruba o worker', function () {
    PixEnviado::dispatch((string) Str::uuid7(), 'evt_x', []);

    expect(Notificacao::count())->toBe(0);
});

// ── turno_cancelado (TurnoCancelado → o OUTRO lado) ───────────────────────────

it('cancelamento pelo profissional notifica o contratante, com motivo (CA-1)', function () {
    $turno = turnoNotificavel('Recepcionista');

    TurnoCancelado::dispatch($turno->id, 'pro', 'Imprevisto de saúde');

    $n = Notificacao::where('tipo', NotificacaoTipo::TurnoCancelado)->first();
    expect($n)->not->toBeNull()
        ->and($n->destinatario_id)->toBe($turno->contratante_id)
        ->and($n->payload['cancelado_por'])->toBe('pelo profissional')
        ->and($n->payload['motivo_texto'])->toContain('Imprevisto de saúde');
});

it('cancelamento pelo contratante notifica o profissional; sem motivo → texto padrão (CA-1)', function () {
    $turno = turnoNotificavel();

    TurnoCancelado::dispatch($turno->id, 'emp', null);

    $n = Notificacao::where('tipo', NotificacaoTipo::TurnoCancelado)->first();
    expect($n)->not->toBeNull()
        ->and($n->destinatario_id)->toBe($turno->profissional_id)
        ->and($n->payload['cancelado_por'])->toBe('pelo contratante')
        // Renderer bloqueia placeholder vazio — motivo_texto é SEMPRE não-vazio (spec §5).
        ->and($n->payload['motivo_texto'])->toBe('Nenhum motivo foi informado.');
});

it('TurnoCancelado é idempotente (CA-3)', function () {
    $turno = turnoNotificavel();

    TurnoCancelado::dispatch($turno->id, 'pro', null);
    TurnoCancelado::dispatch($turno->id, 'pro', null);

    expect(Notificacao::where('tipo', NotificacaoTipo::TurnoCancelado)->count())->toBe(1);
});

// ── no_show_pro (TurnoNoShow → AMBOS os lados) ────────────────────────────────

it('no-show notifica os dois lados com o prazo, idempotente (CA-1/CA-3)', function () {
    config(['turno.no_show_horas' => 2]);
    $turno = turnoNotificavel(status: TurnoStatus::NoShowPro);

    TurnoNoShow::dispatch($turno->id);
    TurnoNoShow::dispatch($turno->id);

    $ns = Notificacao::where('tipo', NotificacaoTipo::NoShowPro)->get();
    expect($ns)->toHaveCount(2)
        ->and($ns->pluck('destinatario_id')->sort()->values()->all())
        ->toBe(collect([$turno->profissional_id, $turno->contratante_id])->sort()->values()->all())
        ->and($ns->first()->payload['no_show_prazo'])->toBe('2 horas');
});

// ── fila de e-mail (CA-2) ─────────────────────────────────────────────────────

it('cada notificação de turno entra na fila de e-mail (job na fila database — CA-2)', function () {
    $turno = turnoNotificavel();

    TurnoCriado::dispatch($turno->id);

    // Fila implícita: criada e ainda não enviada; e o job foi para a tabela `jobs`.
    $n = Notificacao::where('tipo', NotificacaoTipo::TurnoConfirmado)->first();
    expect($n->enviada_email_em)->toBeNull()
        ->and(DB::table('jobs')->count())->toBeGreaterThanOrEqual(1);
});
