<?php

// STORY-092 / ADR-020 (Decisão 4 / CA-6) — DisputaAberta → `disputa_aberta` ao PROFISSIONAL
// (in-app + e-mail, SLA 30 min). Evento despachado de verdade (sem Event::fake) para exercitar
// o registro do AppServiceProvider. A justificativa do contratante NÃO entra no payload
// (DDR-005 Decisão 2 — o profissional não a vê). Idempotente por `disputa_aberta:{turno}`.

use App\Enums\NotificacaoTipo;
use App\Enums\TurnoStatus;
use App\Events\DisputaAberta;
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

/** Turno coerente p/ o payload comum (função nomeada, contratante com perfil, datas fixas). */
function turnoEmDisputa(string $funcao = 'Garçom'): Turno
{
    $vaga = Vaga::factory()->create([
        'funcao_id' => Funcao::factory()->create(['nome' => $funcao])->id,
        'data_inicio' => Carbon::parse('2026-07-01 21:00', 'UTC'),
        'data_fim' => Carbon::parse('2026-07-02 02:00', 'UTC'),
    ]);

    $turno = Turno::factory()->status(TurnoStatus::EmDisputa)->create([
        'vaga_id' => $vaga->id,
        'contratante_id' => $vaga->contratante_id,
        'estabelecimento_id' => $vaga->contratante_id,
        'valor' => 200.00,
        'taxa_turni' => 30.00,
        'total_contratante' => 230.00,
        'data_inicio' => $vaga->data_inicio,
        'data_fim' => $vaga->data_fim,
        'disputa' => [
            'aberta_em' => now()->toIso8601String(),
            'aberta_por' => $vaga->contratante_id,
            'justificativa_contratante' => 'segredo do contratante que o profissional NÃO pode ver',
            'resolucao' => null,
            'nota_admin' => null,
            'resolvida_em' => null,
            'resolvida_por' => null,
        ],
    ]);

    ContratanteProfile::create([
        'user_id' => $turno->contratante_id,
        'nome_estabelecimento' => 'Restaurante Vela Ltda',
        'apelido_estabelecimento' => 'Vela Bar',
    ]);

    return $turno;
}

it('CA-6: DisputaAberta notifica o PROFISSIONAL com disputa_aberta e payload comum', function () {
    $turno = turnoEmDisputa('Cozinheiro');

    DisputaAberta::dispatch($turno->id);

    $n = Notificacao::where('tipo', NotificacaoTipo::DisputaAberta)->first();
    expect($n)->not->toBeNull()
        ->and($n->destinatario_id)->toBe($turno->profissional_id)
        ->and($n->idempotency_key)->toBe("disputa_aberta:{$turno->id}")
        ->and($n->payload['vaga_funcao'])->toBe('Cozinheiro')
        ->and($n->payload['estabelecimento_nome'])->toBe('Vela Bar')
        ->and($n->payload['link_turno'])->toContain("/turnos/{$turno->id}");
});

it('CA-6: a justificativa do contratante NÃO vaza no payload da notificação (DDR-005)', function () {
    $turno = turnoEmDisputa();

    DisputaAberta::dispatch($turno->id);

    $n = Notificacao::where('tipo', NotificacaoTipo::DisputaAberta)->first();
    expect($n->payload)->not->toHaveKey('justificativa_contratante')
        ->and(json_encode($n->payload))->not->toContain('segredo do contratante');
});

it('CA-6: DisputaAberta é idempotente — replay do evento não duplica', function () {
    $turno = turnoEmDisputa();

    DisputaAberta::dispatch($turno->id);
    DisputaAberta::dispatch($turno->id);

    expect(Notificacao::where('tipo', NotificacaoTipo::DisputaAberta)->count())->toBe(1);
});

it('CA-6: a notificação entra na fila de e-mail (job na fila database)', function () {
    $turno = turnoEmDisputa();

    DisputaAberta::dispatch($turno->id);

    $n = Notificacao::where('tipo', NotificacaoTipo::DisputaAberta)->first();
    expect($n->enviada_email_em)->toBeNull()
        ->and(DB::table('jobs')->count())->toBeGreaterThanOrEqual(1);
});

it('turno desconhecido não cria notificação nem derruba o worker', function () {
    DisputaAberta::dispatch((string) Str::uuid7());

    expect(Notificacao::count())->toBe(0);
});
