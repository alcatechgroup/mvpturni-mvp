<?php

// STORY-019 — componente Livewire da fila de aprovação (rota, lista, filtros, ações).

use App\Livewire\FilaAprovacao;
use App\Models\AdminAuditLog;
use App\Models\ProfissionalProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Livewire\Livewire;
use Turni\Domain\Email\EnviarEmailTransacionalJob;

uses(RefreshDatabase::class);

// ──────────────────────────────────────────────────────────────
// CA-1: rota /aprovacoes — admin 200, demais fail-secure
// ──────────────────────────────────────────────────────────────

test('rota /aprovacoes responde 200 para admin autenticado', function () {
    $admin = User::factory()->admin()->create();
    $this->actingAs($admin)->get('/aprovacoes')->assertOk()->assertSee('Cadastros pendentes');
});

test('rota /aprovacoes redireciona não-autenticado para /login', function () {
    $this->get('/aprovacoes')->assertRedirect('/login');
});

test('rota /aprovacoes retorna 403 para não-admin autenticado', function () {
    $prof = User::factory()->profissional()->create();
    $this->actingAs($prof)->get('/aprovacoes')->assertStatus(403);
});

// ──────────────────────────────────────────────────────────────
// CA-2: lista FIFO de pendentes
// ──────────────────────────────────────────────────────────────

test('lista mostra apenas pendentes em ordem FIFO', function () {
    $admin = User::factory()->admin()->create();
    $velho = User::factory()->profissional()->create(['name' => 'Velho', 'created_at' => now()->subDays(2)]);
    $novo = User::factory()->profissional()->create(['name' => 'Novo', 'created_at' => now()->subHour()]);
    User::factory()->profissional()->ativo()->create(['name' => 'JaAtivo']); // não pendente

    Livewire::actingAs($admin)->test(FilaAprovacao::class)
        ->assertSeeInOrder(['Velho', 'Novo'])
        ->assertDontSee('JaAtivo');
});

// ──────────────────────────────────────────────────────────────
// CA-3: filtros e contador agregado
// ──────────────────────────────────────────────────────────────

test('filtro por papel restringe a lista', function () {
    $admin = User::factory()->admin()->create();
    User::factory()->profissional()->create(['name' => 'ProfA']);
    User::factory()->contratante()->create(['name' => 'ContrB']);

    Livewire::actingAs($admin)->test(FilaAprovacao::class)
        ->set('papel', 'contratante')
        ->assertSee('ContrB')
        ->assertDontSee('ProfA');
});

test('filtro por tipo_pessoa restringe profissionais', function () {
    $admin = User::factory()->admin()->create();
    $mei = User::factory()->profissional()->create(['name' => 'MeiCarlos']);
    ProfissionalProfile::factory()->for($mei)->tipo('MEI')->create();
    $pf = User::factory()->profissional()->create(['name' => 'PfDiego']);
    ProfissionalProfile::factory()->for($pf)->tipo('PF')->create();

    Livewire::actingAs($admin)->test(FilaAprovacao::class)
        ->set('papel', 'profissional')
        ->call('filtrarTipo', 'MEI')
        ->assertSee('MeiCarlos')
        ->assertDontSee('PfDiego');
});

test('contador agregado reflete o backlog por papel e tipo', function () {
    $admin = User::factory()->admin()->create();
    $mei = User::factory()->profissional()->create();
    ProfissionalProfile::factory()->for($mei)->tipo('MEI')->create();
    $pf = User::factory()->profissional()->create();
    ProfissionalProfile::factory()->for($pf)->tipo('PF')->create();
    User::factory()->contratante()->create();

    $c = Livewire::actingAs($admin)->test(FilaAprovacao::class)->instance()->contadores;

    expect($c['total'])->toBe(3)
        ->and($c['profissionais'])->toBe(2)
        ->and($c['contratantes'])->toBe(1)
        ->and($c['mei'])->toBe(1)
        ->and($c['pf'])->toBe(1);
});

// ──────────────────────────────────────────────────────────────
// CA-5: aprovar pelo componente
// ──────────────────────────────────────────────────────────────

test('aprovar pelo componente transiciona, audita, despacha e some da lista', function () {
    Queue::fake();
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->profissional()->create(['name' => 'AprovarMe']);

    Livewire::actingAs($admin)->test(FilaAprovacao::class)
        ->call('verDetalhes', $alvo->id)
        ->call('aprovar')
        ->assertDispatched('toast')
        ->assertDontSee('AprovarMe');

    expect($alvo->fresh()->status)->toBe('liberado');
    expect(AdminAuditLog::where('action', 'admin.user.approved')->count())->toBe(1);
    Queue::assertPushed(EnviarEmailTransacionalJob::class);
});

// ──────────────────────────────────────────────────────────────
// CA-6: race condition pela UI
// ──────────────────────────────────────────────────────────────

test('aprovar cadastro já processado por outro admin mostra toast de erro', function () {
    Queue::fake();
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->profissional()->create();

    $comp = Livewire::actingAs($admin)->test(FilaAprovacao::class)
        ->call('verDetalhes', $alvo->id);

    // Outro admin aprova "no meio" — fora desta instância.
    $alvo->update(['status' => 'liberado']);

    $comp->call('aprovar')
        ->assertDispatched('toast', message: 'Este cadastro já foi processado por outro admin.', type: 'error');

    expect(AdminAuditLog::where('action', 'admin.user.approved')->count())->toBe(0);
});

// ──────────────────────────────────────────────────────────────
// CA-8: remover pelo componente
// ──────────────────────────────────────────────────────────────

test('remover pelo componente marca recusado, audita e some da lista', function () {
    $admin = User::factory()->admin()->create();
    $alvo = User::factory()->contratante()->create(['name' => 'RemoverMe']);

    Livewire::actingAs($admin)->test(FilaAprovacao::class)
        ->call('verDetalhes', $alvo->id)
        ->call('remover')
        ->assertDispatched('toast')
        ->assertDontSee('RemoverMe');

    expect($alvo->fresh()->status)->toBe('recusado');
    expect(AdminAuditLog::where('action', 'admin.user.removed')->count())->toBe(1);
});
