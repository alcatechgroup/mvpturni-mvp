<?php

// STORY-053 (CA-7) — GET /api/notificacoes, POST .../marcar-lida, POST .../marcar-todas-lidas.
// Cobre: caixa do próprio usuário (criada_em DESC), filtro ?lidas=false, contagem nao_lidas p/
// badge, limite 50, marcar uma/todas, RBAC (404 p/ notificação de terceiro), 401 sem sessão.

use App\Enums\NotificacaoTipo;
use App\Models\Notificacao;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

function usuarioAtivo(): User
{
    return User::factory()->profissional()->ativo()->create();
}

function notif(User $dono, array $over = []): Notificacao
{
    return Notificacao::factory()->create(array_merge([
        'destinatario_id' => $dono->id,
        'tipo' => NotificacaoTipo::VagaCancelada,
        'vaga_id' => null,
        'payload' => ['vaga_funcao' => 'Garçom'],
    ], $over));
}

it('lista as notificações do próprio usuário em criada_em DESC com contagem de não-lidas', function () {
    $user = usuarioAtivo();
    notif($user, ['criada_em' => now()->subHours(2), 'lida_em' => now()]);
    $recente = notif($user, ['criada_em' => now()->subMinutes(5)]);
    // Notificação de outro usuário não aparece.
    notif(usuarioAtivo());

    $res = $this->actingAs($user)->getJson('/api/notificacoes');

    $res->assertStatus(200)
        ->assertJsonCount(2, 'notificacoes')
        ->assertJsonPath('notificacoes.0.id', $recente->id) // mais recente primeiro
        ->assertJsonPath('nao_lidas', 1)
        ->assertJsonStructure([
            'notificacoes' => [['id', 'tipo', 'vaga_id', 'candidatura_id', 'payload', 'lida_em', 'criada_em']],
            'nao_lidas',
        ]);
});

it('filtra só as não-lidas com ?lidas=false', function () {
    $user = usuarioAtivo();
    notif($user, ['lida_em' => now()]);
    notif($user);
    notif($user);

    $this->actingAs($user)->getJson('/api/notificacoes?lidas=false')
        ->assertStatus(200)
        ->assertJsonCount(2, 'notificacoes')
        ->assertJsonPath('nao_lidas', 2);
});

it('limita a 50 a lista mas conta todas as não-lidas no badge', function () {
    $user = usuarioAtivo();
    Notificacao::factory()->count(55)->create(['destinatario_id' => $user->id, 'tipo' => NotificacaoTipo::VagaCancelada]);

    $this->actingAs($user)->getJson('/api/notificacoes')
        ->assertStatus(200)
        ->assertJsonCount(50, 'notificacoes')
        ->assertJsonPath('nao_lidas', 55);
});

it('marca uma notificação como lida', function () {
    $user = usuarioAtivo();
    $n = notif($user);

    $this->actingAs($user)->postJson("/api/notificacoes/{$n->id}/marcar-lida")
        ->assertStatus(200)
        ->assertJsonPath('ok', true);

    expect($n->fresh()->lida_em)->not->toBeNull();
});

it('não deixa marcar como lida a notificação de outro usuário (404)', function () {
    $user = usuarioAtivo();
    $alheia = notif(usuarioAtivo());

    $this->actingAs($user)->postJson("/api/notificacoes/{$alheia->id}/marcar-lida")
        ->assertStatus(404);

    expect($alheia->fresh()->lida_em)->toBeNull();
});

it('marca todas como lidas', function () {
    $user = usuarioAtivo();
    notif($user);
    notif($user);
    notif($user, ['lida_em' => now()]);

    $this->actingAs($user)->postJson('/api/notificacoes/marcar-todas-lidas')
        ->assertStatus(200)
        ->assertJsonPath('marcadas', 2);

    expect(Notificacao::where('destinatario_id', $user->id)->whereNull('lida_em')->count())->toBe(0);
});

it('exige sessão (401)', function () {
    $this->getJson('/api/notificacoes')->assertStatus(401);
});
