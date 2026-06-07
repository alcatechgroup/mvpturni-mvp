<?php

// STORY-075 — banner global "Ambiente de teste — pagamentos simulados" (PDR-017).
// Visível em toda tela autenticada do Backoffice quando turni.env=homolog;
// nunca em production/local nem nas telas pré-auth (login). Em homolog o
// Laravel roda com APP_ENV=production (otimizações), por isso a detecção usa
// a env var dedicada TURNI_ENV — não app()->environment().

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

const MICROCOPY = 'Ambiente de teste — pagamentos simulados';

test('CA-1: banner visível no dashboard quando turni.env=homolog', function () {
    config(['turni.env' => 'homolog']);
    $admin = User::factory()->admin()->create();

    $this->actingAs($admin)->get('/')
        ->assertOk()
        ->assertSee(MICROCOPY)
        ->assertSee('data-testid="env-banner"', false)
        ->assertSee('role="status"', false); // CA-7 — anunciado como status
});

test('CA-1: banner presente também nas demais telas autenticadas (fila de aprovação)', function () {
    config(['turni.env' => 'homolog']);
    $admin = User::factory()->admin()->create();

    $this->actingAs($admin)->get('/aprovacoes')
        ->assertOk()
        ->assertSee(MICROCOPY);
});

test('CA-2: banner NÃO aparece quando turni.env=production', function () {
    config(['turni.env' => 'production']);
    $admin = User::factory()->admin()->create();

    $this->actingAs($admin)->get('/')
        ->assertOk()
        ->assertDontSee(MICROCOPY);
});

test('CA-2: banner NÃO aparece quando turni.env=local (dev)', function () {
    config(['turni.env' => 'local']);
    $admin = User::factory()->admin()->create();

    $this->actingAs($admin)->get('/')
        ->assertOk()
        ->assertDontSee(MICROCOPY);
});

test('borda fail-safe: valor de ambiente desconhecido NÃO mostra o banner', function () {
    config(['turni.env' => 'staging']);
    $admin = User::factory()->admin()->create();

    $this->actingAs($admin)->get('/')
        ->assertOk()
        ->assertDontSee(MICROCOPY);
});

test('borda fail-safe: turni.env ausente (null) NÃO mostra o banner', function () {
    config(['turni.env' => null]);
    $admin = User::factory()->admin()->create();

    $this->actingAs($admin)->get('/')
        ->assertOk()
        ->assertDontSee(MICROCOPY);
});

test('CA-4: login (pré-auth) NÃO exibe o banner mesmo em homolog', function () {
    config(['turni.env' => 'homolog']);

    $this->get('/login')
        ->assertOk()
        ->assertDontSee(MICROCOPY);
});

test('CA-5: banner não tem botão de fechar (não-dispensável)', function () {
    config(['turni.env' => 'homolog']);
    $admin = User::factory()->admin()->create();

    $html = $this->actingAs($admin)->get('/')->getContent();

    // Recorta o markup do banner e garante que não há controle interativo nele.
    expect($html)->toContain('data-testid="env-banner"');
    $start = strpos($html, 'data-testid="env-banner"');
    $fragment = substr($html, $start, strpos($html, '</div>', $start) - $start);
    expect($fragment)->not->toContain('<button')
        ->and($fragment)->not->toContain('onclick');
});

test('CA-6: banner consome tokens do DS (warning-soft / warning), sem cor nova', function () {
    config(['turni.env' => 'homolog']);
    $admin = User::factory()->admin()->create();

    $html = $this->actingAs($admin)->get('/')->getContent();
    $start = strpos($html, 'class="env-banner"');
    expect($start)->not->toBeFalse();

    // O CSS da faixa usa as variáveis do DS (DDR-001), não hex novo.
    expect($html)->toContain('--warning-soft')
        ->and($html)->toContain('var(--warning)');
});
