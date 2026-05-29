<?php

// STORY-019 — CA-1: a fila é acessível pelo menu de navegação principal a partir do dashboard.

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('dashboard do admin tem link para a fila de aprovação no menu', function () {
    $admin = User::factory()->admin()->create();

    $this->actingAs($admin)->get('/')
        ->assertOk()
        ->assertSee('Cadastros pendentes')
        ->assertSee(route('aprovacoes'), false); // o menu lateral aponta para /aprovacoes
});

test('a fila renderiza o item de menu ativo', function () {
    $admin = User::factory()->admin()->create();

    $this->actingAs($admin)->get('/aprovacoes')
        ->assertOk()
        ->assertSee('Cadastros pendentes');
});
