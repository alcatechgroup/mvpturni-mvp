<?php

// STORY-016 — CA-6, CA-8 — Login do Backoffice (guard web + audit log)

use App\Models\AdminAuditLog;
use App\Models\User;
use Illuminate\Foundation\Http\Middleware\PreventRequestForgery;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;

uses(RefreshDatabase::class);

// Desabilita CSRF para todos os testes deste arquivo.
// Em produção, o @csrf no blade garante o token; em testes, validado pelo E2E (CA-13).
beforeEach(function () {
    // Laravel 13: CSRF middleware renomeado para PreventRequestForgery.
    // Desabilitado nos testes pois o fluxo real (form @csrf) é validado no E2E (CA-13).
    $this->withoutMiddleware(PreventRequestForgery::class);
});

// ──────────────────────────────────────────────────────────────
// CA-6: Login do admin com sucesso
// ──────────────────────────────────────────────────────────────

test('admin faz login com sucesso e é redirecionado para dashboard', function () {
    $admin = User::factory()->admin()->create([
        'email' => 'admin@turni.local',
        'password' => Hash::make('senha-admin'),
    ]);

    $response = $this->post('/login', [
        'email' => 'admin@turni.local',
        'password' => 'senha-admin',
    ]);

    $response->assertRedirect('/');
    $this->assertAuthenticatedAs($admin);
});

test('login do admin grava admin.login no audit log', function () {
    User::factory()->admin()->create([
        'email' => 'admin@turni.local',
        'password' => Hash::make('senha-admin'),
    ]);

    $this->post('/login', [
        'email' => 'admin@turni.local',
        'password' => 'senha-admin',
    ]);

    expect(AdminAuditLog::where('action', 'admin.login')->count())->toBe(1);
});

test('login com credencial inválida retorna erro sem revelar e-mail', function () {
    User::factory()->admin()->create(['email' => 'admin@turni.local']);

    $response = $this->post('/login', [
        'email' => 'admin@turni.local',
        'password' => 'senha-errada',
    ]);

    $response->assertSessionHasErrors(['email']);
    $this->assertGuest();
});

test('login com credencial inválida grava admin.login_failed no audit log', function () {
    User::factory()->admin()->create(['email' => 'admin@turni.local']);

    $this->post('/login', [
        'email' => 'admin@turni.local',
        'password' => 'senha-errada',
    ]);

    expect(AdminAuditLog::where('action', 'admin.login_failed')->count())->toBe(1);
});

test('login com campos vazios retorna erro de validação', function () {
    $this->post('/login', [])->assertSessionHasErrors(['email', 'password']);
    $this->assertGuest();
});

// ──────────────────────────────────────────────────────────────
// CA-8: Não-admin tentando logar no Backoffice → 403 fail-secure
// ──────────────────────────────────────────────────────────────

test('contratante tentando logar no backoffice é rejeitado com 403', function () {
    User::factory()->contratante()->ativo()->create([
        'email' => 'contratante@turni.local',
        'password' => Hash::make('senha-teste'),
    ]);

    $response = $this->post('/login', [
        'email' => 'contratante@turni.local',
        'password' => 'senha-teste',
    ]);

    $response->assertStatus(403);
    $this->assertGuest();
});

test('profissional tentando logar no backoffice é rejeitado com 403', function () {
    User::factory()->profissional()->ativo()->create([
        'email' => 'prof@turni.local',
        'password' => Hash::make('senha-teste'),
    ]);

    $response = $this->post('/login', [
        'email' => 'prof@turni.local',
        'password' => 'senha-teste',
    ]);

    $response->assertStatus(403);
    $this->assertGuest();
});

test('tentativa de não-admin no backoffice grava admin.login_attempt_non_admin no audit log', function () {
    User::factory()->contratante()->ativo()->create([
        'email' => 'contratante@turni.local',
        'password' => Hash::make('senha-teste'),
    ]);

    $this->post('/login', [
        'email' => 'contratante@turni.local',
        'password' => 'senha-teste',
    ]);

    expect(AdminAuditLog::where('action', 'admin.login_attempt_non_admin')->count())->toBe(1);
});

// ──────────────────────────────────────────────────────────────
// Proteção de rotas — usuário não-autenticado é redirecionado
// ──────────────────────────────────────────────────────────────

test('rota protegida redireciona para /login quando não autenticado', function () {
    $this->get('/')->assertRedirect('/login');
});

test('rota protegida retorna 200 para admin autenticado', function () {
    $admin = User::factory()->admin()->create();
    $this->actingAs($admin)->get('/')->assertStatus(200);
});

// ──────────────────────────────────────────────────────────────
// Logout
// ──────────────────────────────────────────────────────────────

test('logout invalida sessão e redireciona para /login', function () {
    $admin = User::factory()->admin()->create();
    $this->actingAs($admin)->post('/logout')->assertRedirect('/login');
    $this->assertGuest();
});
