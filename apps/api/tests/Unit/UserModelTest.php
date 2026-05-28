<?php

// STORY-016 — CA-14 — Testes do modelo User (máquina de estado do funil).
// Núcleo deve ter ≥98% de cobertura (quality-standards.md §1.1).
// Usa RefreshDatabase para os testes com datetime casting do Eloquent.

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

// ──────────────────────────────────────────────────────────────
// Helpers de papel
// ──────────────────────────────────────────────────────────────

test('isAdmin retorna true para role=admin', function () {
    $user = new User(['role' => 'admin', 'status' => 'ativo']);
    expect($user->isAdmin())->toBeTrue();
});

test('isAdmin retorna false para role=profissional', function () {
    $user = new User(['role' => 'profissional', 'status' => 'ativo']);
    expect($user->isAdmin())->toBeFalse();
});

test('isProfissional retorna true para role=profissional', function () {
    $user = new User(['role' => 'profissional', 'status' => 'ativo']);
    expect($user->isProfissional())->toBeTrue();
});

test('isProfissional retorna false para role=contratante', function () {
    $user = new User(['role' => 'contratante', 'status' => 'ativo']);
    expect($user->isProfissional())->toBeFalse();
});

test('isContratante retorna true para role=contratante', function () {
    $user = new User(['role' => 'contratante', 'status' => 'ativo']);
    expect($user->isContratante())->toBeTrue();
});

test('canAccessWebApp retorna true para contratante', function () {
    $user = new User(['role' => 'contratante', 'status' => 'ativo']);
    expect($user->canAccessWebApp())->toBeTrue();
});

test('canAccessWebApp retorna true para profissional', function () {
    $user = new User(['role' => 'profissional', 'status' => 'ativo']);
    expect($user->canAccessWebApp())->toBeTrue();
});

test('canAccessWebApp retorna false para admin', function () {
    $user = new User(['role' => 'admin', 'status' => 'ativo']);
    expect($user->canAccessWebApp())->toBeFalse();
});

// ──────────────────────────────────────────────────────────────
// Helpers de status
// ──────────────────────────────────────────────────────────────

test('isAtivo retorna true para status=ativo', function () {
    $user = new User(['status' => 'ativo']);
    expect($user->isAtivo())->toBeTrue();
});

test('isAtivo retorna false para status=liberado', function () {
    $user = new User(['status' => 'liberado']);
    expect($user->isAtivo())->toBeFalse();
});

test('isLiberado retorna true para status=liberado', function () {
    $user = new User(['status' => 'liberado']);
    expect($user->isLiberado())->toBeTrue();
});

test('isPendente retorna true para status=pendente_aprovacao', function () {
    $user = new User(['status' => 'pendente_aprovacao']);
    expect($user->isPendente())->toBeTrue();
});

// ──────────────────────────────────────────────────────────────
// Máquina de estado do funil (ADR-009 — núcleo — ≥98%)
// ──────────────────────────────────────────────────────────────

test('funnelState retorna await_approval para pendente_aprovacao', function () {
    $user = new User([
        'status' => 'pendente_aprovacao',
        'welcome_seen_at' => null,
        'cadastro_completed_at' => null,
    ]);
    expect($user->funnelState())->toBe('await_approval');
});

test('funnelState retorna rejected para recusado', function () {
    $user = new User([
        'status' => 'recusado',
        'welcome_seen_at' => null,
        'cadastro_completed_at' => null,
    ]);
    expect($user->funnelState())->toBe('rejected');
});

test('funnelState retorna await_welcome para liberado sem welcome', function () {
    $user = new User([
        'status' => 'liberado',
        'welcome_seen_at' => null,
        'cadastro_completed_at' => null,
    ]);
    expect($user->funnelState())->toBe('await_welcome');
});

test('funnelState retorna await_cadastro para liberado com welcome mas sem cadastro', function () {
    $user = new User([
        'status' => 'liberado',
        'welcome_seen_at' => now(),
        'cadastro_completed_at' => null,
    ]);
    expect($user->funnelState())->toBe('await_cadastro');
});

test('funnelState retorna active para usuario ativo', function () {
    $user = new User([
        'status' => 'ativo',
        'welcome_seen_at' => now(),
        'cadastro_completed_at' => now(),
    ]);
    expect($user->funnelState())->toBe('active');
});

test('funnelState retorna active para ativo mesmo com timestamps nulos (admin)', function () {
    $user = new User([
        'status' => 'ativo',
        'welcome_seen_at' => null,
        'cadastro_completed_at' => null,
    ]);
    // Admin nasce ativo com timestamps null — ainda deve ser active
    expect($user->funnelState())->toBe('active');
});
