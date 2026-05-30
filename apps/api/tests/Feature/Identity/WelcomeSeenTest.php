<?php

// STORY-022 — POST /api/usuarios/me/welcome-visto
// CA-4 (marca welcome_visto + retorna estado), CA-8 (idempotência), CA-12 (log estruturado).

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

uses(RefreshDatabase::class);

// ──────────────────────────────────────────────────────────────
// CA-4 — marca welcome_seen_at e retorna o novo estado
// ──────────────────────────────────────────────────────────────

test('usuário liberado com welcome_visto=false marca welcome e recebe novo estado', function () {
    $user = User::factory()->profissional()->liberado()->create(['name' => 'Diego Silva']);

    expect($user->welcome_seen_at)->toBeNull();

    $response = $this->actingAs($user)->postJson('/api/usuarios/me/welcome-visto');

    $response->assertStatus(200)
        ->assertJsonStructure(['role', 'status', 'welcome_visto', 'cadastro_completo', 'name'])
        ->assertJsonPath('welcome_visto', true)
        ->assertJsonPath('status', 'liberado')
        ->assertJsonPath('cadastro_completo', false)
        ->assertJsonPath('name', 'Diego Silva');

    expect($user->fresh()->welcome_seen_at)->not->toBeNull();
});

test('o funnel state do usuário avança de await_welcome para await_cadastro após marcar', function () {
    $user = User::factory()->profissional()->liberado()->create();

    expect($user->funnelState())->toBe('await_welcome');

    $this->actingAs($user)->postJson('/api/usuarios/me/welcome-visto')->assertStatus(200);

    expect($user->fresh()->funnelState())->toBe('await_cadastro');
});

// ──────────────────────────────────────────────────────────────
// CA-8 — idempotência: marcar 2× é no-op silencioso (não erra, não sobrescreve)
// ──────────────────────────────────────────────────────────────

test('marcar welcome quando já marcado é no-op silencioso e não sobrescreve o timestamp', function () {
    $jaVisto = now()->subDays(2);
    $user = User::factory()->profissional()->liberado()->create(['welcome_seen_at' => $jaVisto]);

    $response = $this->actingAs($user)->postJson('/api/usuarios/me/welcome-visto');

    $response->assertStatus(200)->assertJsonPath('welcome_visto', true);

    // timestamp original preservado (no-op, não regrava)
    expect($user->fresh()->welcome_seen_at->timestamp)->toBe($jaVisto->timestamp);
});

test('marcar welcome duas vezes seguidas retorna 200 nas duas', function () {
    $user = User::factory()->profissional()->liberado()->create();

    $this->actingAs($user)->postJson('/api/usuarios/me/welcome-visto')->assertStatus(200);
    $this->actingAs($user)->postJson('/api/usuarios/me/welcome-visto')->assertStatus(200);
});

// ──────────────────────────────────────────────────────────────
// CA-7 — proteção: não-autenticado e admin
// ──────────────────────────────────────────────────────────────

test('não-autenticado não pode marcar welcome', function () {
    $this->postJson('/api/usuarios/me/welcome-visto')->assertStatus(401);
});

test('admin não acessa o endpoint do WebApp', function () {
    $admin = User::factory()->admin()->create();

    $this->actingAs($admin)
        ->postJson('/api/usuarios/me/welcome-visto')
        ->assertStatus(403)
        ->assertJsonPath('code', 'admin_must_use_backoffice');
});

// ──────────────────────────────────────────────────────────────
// Acessível por quem está em await_welcome (NÃO bloqueado pelo FunnelGuard)
// ──────────────────────────────────────────────────────────────

test('endpoint welcome-visto NÃO é bloqueado pelo funnel guard para usuário em await_welcome', function () {
    $user = User::factory()->profissional()->liberado()->create();

    // /api/user (com FunnelGuard) bloqueia esse usuário com 423...
    $this->actingAs($user)->getJson('/api/user')->assertStatus(423);

    // ...mas o welcome-visto precisa ser acessível justamente por ele.
    $this->actingAs($user)->postJson('/api/usuarios/me/welcome-visto')->assertStatus(200);
});

// ──────────────────────────────────────────────────────────────
// CA-12 — log estruturado user.welcome_seen, sem PII clara
// ──────────────────────────────────────────────────────────────

test('marcar welcome emite log estruturado user.welcome_seen sem PII clara', function () {
    $user = User::factory()->profissional()->liberado()->create([
        'name' => 'Diego Silva',
        'email' => 'diego.silva@example.com',
    ]);

    Log::spy();

    $this->actingAs($user)->postJson('/api/usuarios/me/welcome-visto')->assertStatus(200);

    Log::shouldHaveReceived('info')
        ->withArgs(function ($message, $context) use ($user) {
            return $message === 'user.welcome_seen'
                && $context['event'] === 'user.welcome_seen'
                && $context['user_id'] === $user->id
                && $context['role'] === 'profissional'
                && isset($context['timestamp'])
                // sem PII: nem nome, nem e-mail claro no contexto
                && ! in_array('Diego Silva', $context, true)
                && ! in_array('diego.silva@example.com', $context, true);
        })
        ->once();
});

// ──────────────────────────────────────────────────────────────
// login agora devolve name (headline personalizada — STORY-022)
// ──────────────────────────────────────────────────────────────

test('login bem-sucedido inclui name no payload', function () {
    User::factory()->profissional()->ativo()->create([
        'name' => 'Ana Costa',
        'email' => 'ana@turni.local',
        'password' => Hash::make('senha-teste'),
    ]);

    $this->postJson('/api/login', ['email' => 'ana@turni.local', 'password' => 'senha-teste'])
        ->assertStatus(200)
        ->assertJsonPath('name', 'Ana Costa');
});
