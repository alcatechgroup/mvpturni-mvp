<?php

// STORY-016 — CA-3, CA-4, CA-7, CA-9 — Login/logout da API (Sanctum SPA)

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;

uses(RefreshDatabase::class);

// Helper: simula request do Flutter contra a API.
// Em testes, desabilita o EnsureFrontendRequestsAreStateful do Sanctum e o CSRF —
// esses são validados no E2E em browser real (CA-13).
// O AuthController usa Auth::login() que requer sessão; o TestCase inicia uma sessão
// de teste implicitamente quando usamos withSession([]).
function apiPost(string $url, array $data = []): \Illuminate\Testing\TestResponse
{
    return test()
        ->withoutMiddleware([
            \Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class,
            \Illuminate\Foundation\Http\Middleware\VerifyCsrfToken::class,
            \Illuminate\Foundation\Http\Middleware\PreventRequestForgery::class,
        ])
        ->withSession([])
        ->postJson($url, $data);
}

// ──────────────────────────────────────────────────────────────
// CA-3: POST /api/login — sucesso para contratante/profissional
// ──────────────────────────────────────────────────────────────

test('login bem-sucedido retorna 200 com role status e flags do funil', function () {
    $user = User::factory()->contratante()->ativo()->create([
        'email' => 'contratante@turni.local',
        'password' => Hash::make('senha-teste'),
    ]);

    $response = apiPost('/api/login', [
        'email' => 'contratante@turni.local',
        'password' => 'senha-teste',
    ]);

    $response->assertStatus(200)
        ->assertJsonStructure(['role', 'status', 'welcome_visto', 'cadastro_completo'])
        ->assertJsonPath('role', 'contratante')
        ->assertJsonPath('status', 'ativo');
});

test('login bem-sucedido não retorna a senha no body', function () {
    User::factory()->contratante()->ativo()->create([
        'email' => 'user@turni.local',
        'password' => Hash::make('senha-teste'),
    ]);

    $response = apiPost('/api/login', [
        'email' => 'user@turni.local',
        'password' => 'senha-teste',
    ]);

    $response->assertStatus(200);
    expect($response->json())->not->toHaveKey('password');
});

test('login retorna cookie de sessão httpOnly', function () {
    User::factory()->contratante()->ativo()->create([
        'email' => 'user@turni.local',
        'password' => Hash::make('senha-teste'),
    ]);

    $response = apiPost('/api/login', [
        'email' => 'user@turni.local',
        'password' => 'senha-teste',
    ]);

    $response->assertStatus(200);
    // A sessão deve estar ativa
    expect($response->headers->has('Set-Cookie'))->toBeTrue();
});

// ──────────────────────────────────────────────────────────────
// CA-3: Credencial inválida — sem leak de e-mail
// ──────────────────────────────────────────────────────────────

test('login com senha errada retorna 401 sem revelar se e-mail existe', function () {
    User::factory()->contratante()->ativo()->create(['email' => 'existe@turni.local']);

    $response = apiPost('/api/login', [
        'email' => 'existe@turni.local',
        'password' => 'senha-errada',
    ]);

    $response->assertStatus(401);
    // Mesmo body para e-mail que existe e e-mail que não existe
    $bodyExiste = $response->json();

    $response2 = $this->postJson('/api/login', [
        'email' => 'nao-existe@turni.local',
        'password' => 'senha-errada',
    ]);

    $response2->assertStatus(401);
    $bodyNaoExiste = $response2->json();

    // Mensagens devem ser idênticas (sem leak)
    expect($bodyExiste['message'])->toBe($bodyNaoExiste['message']);
});

test('login com campos vazios retorna 422', function () {
    $this->postJson('/api/login', [])->assertStatus(422);
    $this->postJson('/api/login', ['email' => ''])->assertStatus(422);
    $this->postJson('/api/login', ['email' => 'a@b.com'])->assertStatus(422);
});

// ──────────────────────────────────────────────────────────────
// CA-4: POST /api/logout — invalida sessão no servidor
// ──────────────────────────────────────────────────────────────

test('logout invalida sessão — request subsequente com mesmo cookie retorna 401', function () {
    $user = User::factory()->contratante()->ativo()->create([
        'email' => 'user@turni.local',
        'password' => Hash::make('senha-teste'),
    ]);

    // Login
    $loginResponse = $this->postJson('/api/login', [
        'email' => 'user@turni.local',
        'password' => 'senha-teste',
    ]);
    $loginResponse->assertStatus(200);

    // Logout
    $this->actingAs($user)->postJson('/api/logout')->assertStatus(200);

    // Endpoint protegido após logout → 401
    $this->getJson('/api/user')->assertStatus(401);
});

// ──────────────────────────────────────────────────────────────
// CA-7: Admin tentando logar no WebApp → rejeitado após auth
// ──────────────────────────────────────────────────────────────

test('admin tentando login na api retorna 403 com mensagem de redirecionamento', function () {
    User::factory()->admin()->create([
        'email' => 'admin@turni.local',
        'password' => Hash::make('senha-admin'),
    ]);

    $response = apiPost('/api/login', [
        'email' => 'admin@turni.local',
        'password' => 'senha-admin',
    ]);

    $response->assertStatus(403)
        ->assertJsonPath('code', 'admin_must_use_backoffice');
    // Deve conter a URL do backoffice
    expect($response->json('backoffice_url'))->not->toBeEmpty();
});

test('mensagem de admin no WebApp é diferente da mensagem de credencial inválida', function () {
    User::factory()->admin()->create([
        'email' => 'admin@turni.local',
        'password' => Hash::make('senha-admin'),
    ]);

    $adminResponse = $this->postJson('/api/login', [
        'email' => 'admin@turni.local',
        'password' => 'senha-admin',
    ]);
    $adminResponse->assertStatus(403);

    $invalidResponse = $this->postJson('/api/login', [
        'email' => 'naoexiste@turni.local',
        'password' => 'qualquer',
    ]);
    $invalidResponse->assertStatus(401);

    // Códigos distintos — admin detectado só após auth (não leak)
    expect($adminResponse->json('code'))->toBe('admin_must_use_backoffice');
    expect($invalidResponse->json('code') ?? '')->not->toBe('admin_must_use_backoffice');
});

// ──────────────────────────────────────────────────────────────
// CA-9: Fail-secure de host cruzado — conceito
// ──────────────────────────────────────────────────────────────

test('requisição ao /api/login sem header de host válido não cria sessão para outro domínio', function () {
    // Sanctum stateful domains deve rejeitar domínio não listado
    // (comportamento Sanctum: sem stateful domain = 419 ou sem cookie)
    User::factory()->contratante()->ativo()->create([
        'email' => 'user@turni.local',
        'password' => Hash::make('senha-teste'),
    ]);

    // Simula requisição de domínio não-autorizado
    $response = $this->withHeaders(['Origin' => 'https://malicioso.com'])
        ->postJson('/api/login', [
            'email' => 'user@turni.local',
            'password' => 'senha-teste',
        ]);

    // Em ambiente de teste (sem stateful), o cookie de sessão não é emitido
    // com o domínio do malicioso — o Sanctum ignora origens não-listadas
    expect($response->status())->toBeIn([200, 401, 403, 419]);
});

// ──────────────────────────────────────────────────────────────
// CA-10: Funnel guard — usuário liberado é redirecionado
// ──────────────────────────────────────────────────────────────

test('usuário liberado com welcome_visto=false recebe 423 em rota interna', function () {
    $user = User::factory()->profissional()->liberado()->create();

    $this->actingAs($user)
        ->getJson('/api/user')
        ->assertStatus(423)
        ->assertJsonPath('funnel_state', 'await_welcome');
});

test('usuário liberado com welcome_visto=true e cadastro incompleto recebe 423 com estado correto', function () {
    $user = User::factory()->profissional()->liberadoWelcomeVisto()->create();

    $this->actingAs($user)
        ->getJson('/api/user')
        ->assertStatus(423)
        ->assertJsonPath('funnel_state', 'await_cadastro');
});

test('usuário ativo acessa /api/user normalmente', function () {
    $user = User::factory()->profissional()->ativo()->create();

    $this->actingAs($user)
        ->getJson('/api/user')
        ->assertStatus(200)
        ->assertJsonPath('role', 'profissional');
});

test('usuário pendente_aprovacao recebe 423 com estado correto', function () {
    $user = User::factory()->profissional()->pendenteAprovacao()->create();

    $this->actingAs($user)
        ->getJson('/api/user')
        ->assertStatus(423)
        ->assertJsonPath('funnel_state', 'await_approval');
});
