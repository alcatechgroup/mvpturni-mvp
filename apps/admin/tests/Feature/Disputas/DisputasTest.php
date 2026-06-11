<?php

// STORY-096 / ADR-020 / DDR-005 — fila de disputas + caso com trilha + resolver "pagar integral".
// A fila é DERIVADA do estado `em_disputa` (ADR-020 D4); o caso é agregação de leitura (D6); a
// resolução é um comando da api (IDR-032) — o admin é CLIENTE (Http::fake mocka a api aqui).
// nota_admin é OBRIGATÓRIA (DDR-005 D3 / ADR-020 — diverge da CA-3 "opcional", resolvido a favor
// do ADR). Concorrência: api responde 422 estado_invalido → mensagem clara, sem efeito duplicado.

use App\Livewire\Disputas;
use App\Models\AdminAuditLog;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\Turno;
use App\Models\TurnoAuditLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Livewire\Livewire;

uses(RefreshDatabase::class);

beforeEach(function () {
    config()->set('services.api.internal_url', 'http://api.test');
    config()->set('services.internal.token', 'segredo-de-teste');
});

/** Turno em disputa com partes nomeadas (estabelecimento ⇄ profissional + função). */
function turnoEmDisputa(array $turno = [], int $abertaHaMin = 10, string $estabelecimento = 'Bar do Zé', string $profissional = 'Carlos H. Silva', string $funcao = 'Garçom'): Turno
{
    $contratante = User::factory()->contratante()->create(['name' => $estabelecimento]);
    ContratanteProfile::factory()->create(['user_id' => $contratante->id, 'nome_estabelecimento' => $estabelecimento]);

    $prof = User::factory()->profissional()->create(['name' => $profissional]);
    $f = Funcao::factory()->create(['nome' => $funcao]);
    ProfissionalProfile::factory()->create(['user_id' => $prof->id, 'funcao_id' => $f->id]);

    return Turno::factory()->emDisputa($abertaHaMin)->create(array_merge([
        'contratante_id' => $contratante->id,
        'profissional_id' => $prof->id,
    ], $turno));
}

/** Turno já finalizado de um estabelecimento nomeado (não deve aparecer na fila). */
function turnoFinalizado(string $estabelecimento): Turno
{
    $contratante = User::factory()->contratante()->create(['name' => $estabelecimento]);
    ContratanteProfile::factory()->create(['user_id' => $contratante->id, 'nome_estabelecimento' => $estabelecimento]);

    return Turno::factory()->create(['status' => 'finalizado', 'contratante_id' => $contratante->id]);
}

// ──────────────────────────────────────────────────────────────
// CA-5 — RBAC fail-secure na rota /disputas
// ──────────────────────────────────────────────────────────────
test('CA-5: rota /disputas responde 200 para admin autenticado', function () {
    $admin = User::factory()->admin()->create();
    $this->actingAs($admin)->get('/disputas')->assertOk()->assertSee('Disputas');
});

test('CA-5: rota /disputas redireciona não-autenticado para /login', function () {
    $this->get('/disputas')->assertRedirect('/login');
});

test('CA-5: rota /disputas retorna 403 para não-admin autenticado (sem vazar dados)', function () {
    turnoEmDisputa([], 10, 'Bar Secreto', 'Profissional Secreto');
    $prof = User::factory()->profissional()->create();
    $this->actingAs($prof)->get('/disputas')
        ->assertStatus(403)
        ->assertDontSee('Bar Secreto')
        ->assertDontSee('Profissional Secreto');
});

// ──────────────────────────────────────────────────────────────
// CA-1 — fila derivada de em_disputa, mais antigo primeiro, com partes/valor/SLA
// ──────────────────────────────────────────────────────────────
test('CA-1: fila lista turnos em_disputa, do mais antigo primeiro, com partes e valor', function () {
    $admin = User::factory()->admin()->create();
    turnoEmDisputa(['valor' => 264.00], abertaHaMin: 18, estabelecimento: 'Hotel Aurora', profissional: 'Ana Lima', funcao: 'Cozinheira'); // mais recente
    turnoEmDisputa(['valor' => 230.00], abertaHaMin: 42, estabelecimento: 'Bar do Zé', profissional: 'Carlos H. Silva', funcao: 'Garçom'); // mais antiga

    Livewire::actingAs($admin)->test(Disputas::class)
        ->assertSeeInOrder(['Bar do Zé', 'Hotel Aurora']) // mais antiga (42 min) antes da recente (18 min)
        ->assertSee('Carlos H. Silva')
        ->assertSee('Garçom')
        ->assertSee('R$ 230,00')
        ->assertSee('R$ 264,00');
});

test('CA-1: turnos fora de em_disputa não aparecem na fila', function () {
    $admin = User::factory()->admin()->create();
    turnoEmDisputa([], 10, 'Em Disputa Ltda');
    turnoFinalizado('Finalizado Ltda');

    $c = Livewire::actingAs($admin)->test(Disputas::class)
        ->assertSee('Em Disputa Ltda')
        ->assertDontSee('Finalizado Ltda');
    expect($c->instance()->abertosCount)->toBe(1);
});

test('CA-1/CA-4: contadores — em aberto e SLA estourado (>30 min)', function () {
    $admin = User::factory()->admin()->create();
    turnoEmDisputa([], 42); // estourado
    turnoEmDisputa([], 18); // dentro do SLA

    $c = Livewire::actingAs($admin)->test(Disputas::class);
    expect($c->instance()->abertosCount)->toBe(2);
    expect($c->instance()->slaEstouradoCount)->toBe(1);
});

test('CA-1: SLA classifica verde (≤15), amarelo (15–30) e vermelho (>30)', function () {
    $admin = User::factory()->admin()->create();
    $c = Livewire::actingAs($admin)->test(Disputas::class)->instance();
    expect($c->slaNivel(10))->toBe('ok');
    expect($c->slaNivel(15))->toBe('ok');
    expect($c->slaNivel(20))->toBe('warn');
    expect($c->slaNivel(30))->toBe('warn');
    expect($c->slaNivel(42))->toBe('late');
});

// ──────────────────────────────────────────────────────────────
// CA-4 — estados: fila vazia / loading / erro de carga
// ──────────────────────────────────────────────────────────────
test('CA-4: fila vazia mostra estado vazio positivo (nenhuma disputa aberta)', function () {
    $admin = User::factory()->admin()->create();
    Livewire::actingAs($admin)->test(Disputas::class)
        ->assertSee('Nenhuma disputa aberta')
        ->assertSet('abertosCount', 0);
});

// ──────────────────────────────────────────────────────────────
// CA-2 — caso: justificativa + trilha (agregação de leitura)
// ──────────────────────────────────────────────────────────────
test('CA-2: abrir caso mostra a justificativa do contratante em destaque', function () {
    $admin = User::factory()->admin()->create();
    $turno = turnoEmDisputa();
    $turno->update(['disputa' => array_merge($turno->disputa, [
        'justificativa_contratante' => 'O profissional saiu 40 min antes do fim e não terminou a limpeza.',
    ])]);

    Livewire::actingAs($admin)->test(Disputas::class)
        ->call('abrirCaso', $turno->id)
        ->assertSet('casoId', $turno->id)
        ->assertSee('O profissional saiu 40 min antes do fim e não terminou a limpeza.');
});

test('CA-2: a trilha compõe os audit_logs reais do turno (criado, check-in, disputa aberta)', function () {
    $admin = User::factory()->admin()->create();
    $turno = turnoEmDisputa();
    TurnoAuditLog::factory()->create(['target_id' => $turno->id, 'action' => 'turno.criado', 'created_at' => now()->subHours(6)]);
    TurnoAuditLog::factory()->create(['target_id' => $turno->id, 'action' => 'turno.checkin_validado', 'created_at' => now()->subHours(5)]);
    TurnoAuditLog::factory()->create(['target_id' => $turno->id, 'action' => 'turno.disputa_aberta', 'created_at' => now()->subMinutes(10)]);

    Livewire::actingAs($admin)->test(Disputas::class)
        ->call('abrirCaso', $turno->id)
        ->assertSee('Disputa aberta')
        ->assertSee('Check-in validado')
        ->assertSee('Turno confirmado'); // rótulo amigável de turno.criado
});

test('CA-2: trilha NÃO mostra chat nem checklist (não existem no MVP — sem invenção)', function () {
    $admin = User::factory()->admin()->create();
    $turno = turnoEmDisputa();
    Livewire::actingAs($admin)->test(Disputas::class)
        ->call('abrirCaso', $turno->id)
        ->assertDontSee('Checklist')
        ->assertDontSee('mensagens'); // "Chat (N mensagens)" do protótipo não é renderizado
});

// ──────────────────────────────────────────────────────────────
// CA-3 — resolver "pagar integral" (nota obrigatória, chama a api, sai da fila)
// ──────────────────────────────────────────────────────────────
test('CA-3: nota vazia (ou só espaços) NÃO resolve — erro de validação, sem chamar a api', function () {
    Http::fake();
    $admin = User::factory()->admin()->create();
    $turno = turnoEmDisputa();

    Livewire::actingAs($admin)->test(Disputas::class)
        ->call('abrirCaso', $turno->id)
        ->call('abrirResolucao')
        ->set('nota', '   ')
        ->call('confirmarResolucao')
        ->assertHasErrors(['nota' => 'required']);

    Http::assertNothingSent();
});

test('CA-3: resolver com nota → chama a api (admin_id + nota) e o caso SAI da fila', function () {
    Http::fake(['http://api.test/api/internal/turnos/*/resolver-disputa' => Http::response(['estado' => 'finalizado'], 200)]);
    $admin = User::factory()->admin()->create();
    $turno = turnoEmDisputa([], 10, 'Bar do Zé');

    $componente = Livewire::actingAs($admin)->test(Disputas::class)
        ->call('abrirCaso', $turno->id)
        ->call('abrirResolucao')
        ->set('nota', 'Justificativa procede; pagar integral ao profissional.')
        ->call('confirmarResolucao')
        ->assertSet('casoId', null)        // drawer fechado
        ->assertSet('resolvendoId', null)  // dialog fechado
        ->assertDispatched('toast');

    Http::assertSent(function ($request) use ($turno, $admin) {
        return str_contains($request->url(), "/api/internal/turnos/{$turno->id}/resolver-disputa")
            && $request['admin_id'] === $admin->id
            && $request['nota_admin'] === 'Justificativa procede; pagar integral ao profissional.';
    });

    // Trilha de auditoria do admin (quem clicou no backoffice).
    expect(AdminAuditLog::where('action', 'disputa.resolucao_solicitada')->where('target_id', $turno->id)->exists())->toBeTrue();
});

// ──────────────────────────────────────────────────────────────
// CA-4 — concorrência e erro da resolução
// ──────────────────────────────────────────────────────────────
test('CA-4: concorrência — turno já não está em_disputa no banco → mensagem clara, sem chamar a api', function () {
    Http::fake();
    $admin = User::factory()->admin()->create();
    $turno = turnoEmDisputa();

    // Outro admin resolveu nesse meio-tempo (a api transitou para finalizado).
    $turno->update(['status' => 'finalizado']);

    Livewire::actingAs($admin)->test(Disputas::class)
        ->call('abrirCaso', $turno->id)
        ->call('abrirResolucao')
        ->set('nota', 'Pagar integral.')
        ->call('confirmarResolucao')
        ->assertDispatched('toast', message: 'Esta disputa já foi resolvida por outro admin.', type: 'error')
        ->assertSet('casoId', null);

    Http::assertNothingSent(); // race detectada no banco antes de chamar
});

test('CA-4: concorrência detectada pela api (422 estado_invalido) → mensagem clara, sem efeito duplicado', function () {
    Http::fake(['*' => Http::response(['motivo' => 'estado_invalido', 'estado' => 'finalizado'], 422)]);
    $admin = User::factory()->admin()->create();
    $turno = turnoEmDisputa();

    Livewire::actingAs($admin)->test(Disputas::class)
        ->call('abrirCaso', $turno->id)
        ->call('abrirResolucao')
        ->set('nota', 'Pagar integral.')
        ->call('confirmarResolucao')
        ->assertDispatched('toast', message: 'Esta disputa já foi resolvida por outro admin.', type: 'error');

    // NÃO registra resolução do admin quando não houve resolução de fato.
    expect(AdminAuditLog::where('action', 'disputa.resolucao_solicitada')->exists())->toBeFalse();
});

test('CA-4: erro da api (500/rede) → toast de erro, caso permanece para retry', function () {
    Http::fake(['*' => Http::response('', 500)]);
    $admin = User::factory()->admin()->create();
    $turno = turnoEmDisputa();

    Livewire::actingAs($admin)->test(Disputas::class)
        ->call('abrirCaso', $turno->id)
        ->call('abrirResolucao')
        ->set('nota', 'Pagar integral.')
        ->call('confirmarResolucao')
        ->assertDispatched('toast', type: 'error')
        ->assertSet('casoId', $turno->id); // drawer permanece aberto para retry
});

// ──────────────────────────────────────────────────────────────
// CA-1/sidebar — contador
// ──────────────────────────────────────────────────────────────
test('sidebar/contador: abertosCount reflete o número de disputas em aberto', function () {
    $admin = User::factory()->admin()->create();
    turnoEmDisputa();
    turnoEmDisputa();
    Turno::factory()->create(['status' => 'finalizado']);

    expect(Livewire::actingAs($admin)->test(Disputas::class)->instance()->abertosCount)->toBe(2);
});
