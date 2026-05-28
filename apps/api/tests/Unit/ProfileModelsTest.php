<?php

// STORY-016 — CA-1 — Testes dos modelos de perfil (ProfissionalProfile, ContratanteProfile)

use App\Models\AdminAuditLog;
use App\Models\ContratanteProfile;
use App\Models\ProfissionalProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('ProfissionalProfile pode ser criado e relacionado ao usuário', function () {
    $user = User::factory()->profissional()->ativo()->create();
    $profile = ProfissionalProfile::create([
        'user_id' => $user->id,
        'tipo_pessoa' => 'PF',
    ]);

    expect($profile->user_id)->toBe($user->id);
    expect($profile->tipo_pessoa)->toBe('PF');
    expect($user->profissionalProfile->tipo_pessoa)->toBe('PF');
});

test('ContratanteProfile pode ser criado e relacionado ao usuário', function () {
    $user = User::factory()->contratante()->ativo()->create();
    $profile = ContratanteProfile::create([
        'user_id' => $user->id,
        'nome_estabelecimento' => 'Restaurante Teste',
    ]);

    expect($profile->user_id)->toBe($user->id);
    expect($profile->nome_estabelecimento)->toBe('Restaurante Teste');
    expect($user->contratanteProfile->nome_estabelecimento)->toBe('Restaurante Teste');
});

test('AdminAuditLog relaciona ao usuário pelo actor_id', function () {
    $admin = User::factory()->admin()->create();
    $log = AdminAuditLog::create([
        'actor_id' => $admin->id,
        'action' => 'admin.login',
        'ip' => '127.0.0.1',
        'user_agent' => 'Test',
    ]);

    expect($log->actor->id)->toBe($admin->id);
});
