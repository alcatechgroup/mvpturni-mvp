<?php

// STORY-016 — CA-9 — Middleware WebAppOnly (fail-secure de host)

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('admin autenticado acessando rota /api/user recebe 403 via WebAppOnly', function () {
    $admin = User::factory()->admin()->create();

    $this->actingAs($admin)
        ->getJson('/api/user')
        ->assertStatus(403)
        ->assertJsonPath('code', 'admin_must_use_backoffice');
});

test('contratante ativo acessa /api/user sem ser bloqueado pelo WebAppOnly', function () {
    $user = User::factory()->contratante()->ativo()->create();

    $this->actingAs($user)
        ->getJson('/api/user')
        ->assertStatus(200);
});

test('profissional ativo acessa /api/user sem ser bloqueado pelo WebAppOnly', function () {
    $user = User::factory()->profissional()->ativo()->create();

    $this->actingAs($user)
        ->getJson('/api/user')
        ->assertStatus(200);
});
