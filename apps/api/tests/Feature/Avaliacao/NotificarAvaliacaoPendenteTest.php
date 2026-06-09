<?php

// STORY-085 / ADR-019 Decisão 3 (CA-2) — `TurnoFinalizado` → notificação `avaliacao_pendente`
// ("avalie seu turno") para AMBOS os lados, idempotente. NÃO materializa pendência (Decisão 2:
// pendência é derivada do estado). Evento despachado de verdade (sem Event::fake) para
// exercitar o registro no AppServiceProvider — mesmo padrão de NotificacaoTurnoListenersTest.

use App\Enums\NotificacaoTipo;
use App\Enums\TurnoStatus;
use App\Events\TurnoFinalizado;
use App\Models\ContratanteProfile;
use App\Models\Notificacao;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

function turnoFinalizadoNotificavel(): Turno
{
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    ContratanteProfile::factory()->create(['user_id' => $turno->contratante_id]);

    return $turno->fresh(['vaga.funcao', 'profissional', 'contratante.contratanteProfile']);
}

test('TurnoFinalizado notifica os DOIS lados com avaliacao_pendente (CA-2)', function () {
    $turno = turnoFinalizadoNotificavel();

    TurnoFinalizado::dispatch($turno->id);

    $ns = Notificacao::where('tipo', NotificacaoTipo::AvaliacaoPendente)->get();
    expect($ns)->toHaveCount(2)
        ->and($ns->pluck('destinatario_id')->sort()->values()->all())
        ->toBe(collect([$turno->profissional_id, $turno->contratante_id])->sort()->values()->all());
});

test('reprocessar TurnoFinalizado não duplica as notificações (idempotente — CA-2)', function () {
    $turno = turnoFinalizadoNotificavel();

    TurnoFinalizado::dispatch($turno->id);
    TurnoFinalizado::dispatch($turno->id);

    expect(Notificacao::where('tipo', NotificacaoTipo::AvaliacaoPendente)->count())->toBe(2);
});

test('chave de idempotência é por destinatário (avaliacao_pendente:{turno}:{destinatario})', function () {
    $turno = turnoFinalizadoNotificavel();

    TurnoFinalizado::dispatch($turno->id);

    expect(Notificacao::where('idempotency_key', "avaliacao_pendente:{$turno->id}:{$turno->profissional_id}")->exists())->toBeTrue()
        ->and(Notificacao::where('idempotency_key', "avaliacao_pendente:{$turno->id}:{$turno->contratante_id}")->exists())->toBeTrue();
});

test('turno desconhecido não cria notificação nem derruba o worker (defensivo)', function () {
    TurnoFinalizado::dispatch((string) Str::uuid7());

    expect(Notificacao::where('tipo', NotificacaoTipo::AvaliacaoPendente)->count())->toBe(0);
});
