<?php

// STORY-009 — CA-1 — Verificação da rota raiz do Backoffice.
// Atualizado por STORY-016: a rota raiz agora requer autenticação (AdminOnly).
// Sem auth → redireciona para /login (comportamento correto de RBAC).

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('rota raiz sem auth redireciona para /login (STORY-016)', function () {
    $this->get('/')->assertRedirect('/login');
});

test('rota raiz retorna 200 para admin autenticado (CA-1)', function () {
    $admin = User::factory()->admin()->create();
    $this->actingAs($admin)->get('/')->assertStatus(200);
});

test('dashboard do admin identifica o Backoffice (CA-1)', function () {
    $admin = User::factory()->admin()->create();
    $this->actingAs($admin)->get('/')
        ->assertStatus(200)
        ->assertSee('Backoffice');
});
