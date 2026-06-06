<?php

// STORY-065 (CA-5, CA-8) — fila "Pix com falha" do Backoffice (SCREEN-065 §B).
// Lista paginada de casos pendentes (desc por falhou_em) com badge + valor + chave Pix
// (decifrada via segredo compartilhado — IDR-028) + razão; aba Resolvidos; resolução
// manual com NOTA OBRIGATÓRIA → admin_audit_log; race-safe entre admins.

use App\Livewire\PixFalhas;
use App\Models\AdminAuditLog;
use App\Models\PixFalha;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;

uses(RefreshDatabase::class);

function casoPixFalha(array $attrs = []): PixFalha
{
    return PixFalha::factory()->create($attrs);
}

// ──────────────────────────────────────────────────────────────
// Rota /pix-falhas — admin 200, demais fail-secure
// ──────────────────────────────────────────────────────────────

test('rota /pix-falhas responde 200 para admin autenticado', function () {
    $admin = User::factory()->admin()->create();
    $this->actingAs($admin)->get('/pix-falhas')->assertOk()->assertSee('Pix com falha');
});

test('rota /pix-falhas redireciona não-autenticado para /login', function () {
    $this->get('/pix-falhas')->assertRedirect('/login');
});

test('rota /pix-falhas retorna 403 para não-admin autenticado', function () {
    $prof = User::factory()->profissional()->create();
    $this->actingAs($prof)->get('/pix-falhas')->assertStatus(403);
});

// ──────────────────────────────────────────────────────────────
// CA-5/CA-8 — lista de pendentes (desc), com os dados do tratamento manual
// ──────────────────────────────────────────────────────────────

test('CA-8: pendentes em ordem de falha DESC, com badge, valor, chave decifrada e razão', function () {
    $admin = User::factory()->admin()->create();
    casoPixFalha([
        'profissional_nome' => 'Carlos Henrique Silva',
        'funcao' => 'Garçom', 'estabelecimento' => 'Bar do Zé',
        'valor' => 200.00, 'chave_pix' => 'carlos@pix.me',
        'razao' => 'invalid_pix_key — chave não encontrada',
        'falhou_em' => now()->subDays(2),
    ]);
    casoPixFalha(['profissional_nome' => 'Diego Reis', 'falhou_em' => now()->subHour()]);

    Livewire::actingAs($admin)->test(PixFalhas::class)
        ->assertSeeInOrder(['Diego Reis', 'Carlos Henrique Silva']) // desc (CA-8)
        ->assertSee('Pix falhou — tratamento manual')               // badge CA-5
        ->assertSee('R$ 200,00')
        ->assertSee('carlos@pix.me')                                 // chave decifrada (IDR-028)
        ->assertSee('invalid_pix_key — chave não encontrada');
});

test('caso resolvido NÃO aparece em pendentes; aparece em resolvidos com nota e autor', function () {
    $admin = User::factory()->admin()->create(['name' => 'Alexandro']);
    casoPixFalha(['profissional_nome' => 'Pendente Da Silva']);
    casoPixFalha([
        'profissional_nome' => 'Resolvida Costa',
        'resolvido_em' => now()->subHour(),
        'resolvido_por' => $admin->id,
        'nota_resolucao' => 'Pix manual feito pela conta Turni',
    ]);

    Livewire::actingAs($admin)->test(PixFalhas::class)
        ->assertSee('Pendente Da Silva')
        ->assertDontSee('Resolvida Costa')
        ->set('aba', 'resolvidos')
        ->assertSee('Resolvida Costa')
        ->assertSee('Pix manual feito pela conta Turni')
        ->assertSee('Alexandro')
        ->assertDontSee('Pendente Da Silva');
});

test('chave Pix ausente no snapshot degrada para indicação honesta', function () {
    $admin = User::factory()->admin()->create();
    casoPixFalha(['chave_pix' => null, 'profissional_nome' => 'Sem Chave']);

    Livewire::actingAs($admin)->test(PixFalhas::class)
        ->assertSee('Sem Chave')
        ->assertSee('chave não cadastrada');
});

// ──────────────────────────────────────────────────────────────
// CA-8 — resolução manual com nota obrigatória → audit
// ──────────────────────────────────────────────────────────────

test('CA-8: resolver com nota marca resolvido, registra autor e grava admin_audit_log', function () {
    $admin = User::factory()->admin()->create();
    $caso = casoPixFalha();

    Livewire::actingAs($admin)->test(PixFalhas::class)
        ->call('abrirResolucao', $caso->id)
        ->set('nota', 'Pix manual feito pela conta Turni em 06/06 às 14:20')
        ->call('confirmarResolucao')
        ->assertDispatched('toast', message: 'Caso resolvido. Registrado no histórico de auditoria.', type: 'success');

    $caso->refresh();
    expect($caso->resolvido_em)->not->toBeNull()
        ->and($caso->resolvido_por)->toBe($admin->id)
        ->and($caso->nota_resolucao)->toBe('Pix manual feito pela conta Turni em 06/06 às 14:20');

    $audit = AdminAuditLog::where('action', 'pix_falha.resolvida')->first();
    expect($audit)->not->toBeNull()
        ->and($audit->actor_id)->toBe($admin->id)
        ->and($audit->target_id)->toBe($caso->id)
        ->and($audit->payload['nota'])->toContain('Pix manual');
});

test('CA-8: nota vazia (ou só espaços) NÃO resolve — erro de validação', function () {
    $admin = User::factory()->admin()->create();
    $caso = casoPixFalha();

    Livewire::actingAs($admin)->test(PixFalhas::class)
        ->call('abrirResolucao', $caso->id)
        ->set('nota', '   ')
        ->call('confirmarResolucao')
        ->assertHasErrors(['nota']);

    expect($caso->refresh()->resolvido_em)->toBeNull()
        ->and(AdminAuditLog::where('action', 'pix_falha.resolvida')->count())->toBe(0);
});

test('race: caso já resolvido por outro admin → toast de erro, sem sobrescrever', function () {
    $admin = User::factory()->admin()->create();
    $outro = User::factory()->admin()->create();
    $caso = casoPixFalha();

    $comp = Livewire::actingAs($admin)->test(PixFalhas::class)
        ->call('abrirResolucao', $caso->id);

    // Outro admin resolve no meio do caminho.
    $caso->update(['resolvido_em' => now(), 'resolvido_por' => $outro->id, 'nota_resolucao' => 'já era']);

    $comp->set('nota', 'minha tentativa tardia')
        ->call('confirmarResolucao')
        ->assertDispatched('toast', message: 'Este caso já foi resolvido por outro admin.', type: 'error');

    expect($caso->refresh()->nota_resolucao)->toBe('já era')
        ->and($caso->resolvido_por)->toBe($outro->id);
});

test('resolver caso inexistente (sumiu) → toast de erro, sem explodir', function () {
    $admin = User::factory()->admin()->create();

    Livewire::actingAs($admin)->test(PixFalhas::class)
        ->call('abrirResolucao', '0197a000-0000-7000-8000-000000000000')
        ->set('nota', 'x')
        ->call('confirmarResolucao')
        ->assertDispatched('toast', message: 'Este caso já foi resolvido por outro admin.', type: 'error');
});

// ──────────────────────────────────────────────────────────────
// Estados: vazio + paginação
// ──────────────────────────────────────────────────────────────

test('fila zerada mostra estado vazio positivo', function () {
    $admin = User::factory()->admin()->create();

    Livewire::actingAs($admin)->test(PixFalhas::class)
        ->assertSee('Nenhum Pix com falha')
        ->assertSee('Por enquanto, tudo certo');
});

test('aba resolvidos vazia mostra estado neutro', function () {
    $admin = User::factory()->admin()->create();

    Livewire::actingAs($admin)->test(PixFalhas::class)
        ->set('aba', 'resolvidos')
        ->assertSee('Nenhum caso resolvido ainda');
});

test('paginação: 21º caso (mais antigo, ordem desc) cai para a página 2 (borda)', function () {
    $admin = User::factory()->admin()->create();
    PixFalha::factory()->count(20)->create(['falhou_em' => now()->subHour()]);
    PixFalha::factory()->create([
        'profissional_nome' => 'Fora Da Página Um',
        'falhou_em' => now()->subDays(3), // o mais antigo — último na ordem desc
    ]);

    Livewire::actingAs($admin)->test(PixFalhas::class)
        ->assertDontSee('Fora Da Página Um')
        ->set('paginators.page', 2)
        ->assertSee('Fora Da Página Um');
});

// ──────────────────────────────────────────────────────────────
// Sidebar — contador de pendentes (SCREEN-065 §B.2)
// ──────────────────────────────────────────────────────────────

test('sidebar mostra contador de pendentes quando há casos', function () {
    $admin = User::factory()->admin()->create();
    casoPixFalha();
    casoPixFalha();

    $this->actingAs($admin)->get('/pix-falhas')
        ->assertSee('data-testid="nav-pix-falhas-count"', false)
        ->assertSee('>2<', false);
});
