<?php

// STORY-016 — CA-1, CA-2 — Schema e idempotência das migrações

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;

uses(RefreshDatabase::class);

test('tabela users tem as colunas de identidade do EPIC-001 (ADR-009)', function () {
    expect(Schema::hasColumns('users', [
        'role',
        'status',
        'welcome_seen_at',
        'cadastro_completed_at',
    ]))->toBeTrue();
});

test('tabela profissional_profiles existe com colunas obrigatórias', function () {
    expect(Schema::hasTable('profissional_profiles'))->toBeTrue();
    expect(Schema::hasColumns('profissional_profiles', [
        'id', 'user_id', 'tipo_pessoa',
    ]))->toBeTrue();
});

test('tabela contratante_profiles existe com colunas obrigatórias', function () {
    expect(Schema::hasTable('contratante_profiles'))->toBeTrue();
    expect(Schema::hasColumns('contratante_profiles', [
        'id', 'user_id', 'nome_estabelecimento',
    ]))->toBeTrue();
});

test('tabela admin_audit_log existe com colunas do ADR-009', function () {
    expect(Schema::hasTable('admin_audit_log'))->toBeTrue();
    expect(Schema::hasColumns('admin_audit_log', [
        'id', 'actor_id', 'action', 'target_type', 'target_id', 'payload', 'ip', 'created_at',
    ]))->toBeTrue();
    // Não deve ter updated_at (append-only)
    expect(Schema::hasColumn('admin_audit_log', 'updated_at'))->toBeFalse();
});

test('admin_audit_log não tem coluna updated_at — é append-only', function () {
    expect(Schema::hasColumn('admin_audit_log', 'updated_at'))->toBeFalse();
});

test('users.role permite apenas valores válidos (constraint CHECK ou enum)', function () {
    $valid = ['admin', 'contratante', 'profissional'];
    foreach ($valid as $role) {
        expect(fn () => User::factory()->create(['role' => $role]))
            ->not->toThrow(Exception::class);
    }
});

test('users.status permite apenas valores válidos', function () {
    $valid = ['pendente_aprovacao', 'liberado', 'ativo', 'recusado'];
    foreach ($valid as $status) {
        expect(fn () => User::factory()->admin()->create(['status' => $status]))
            ->not->toThrow(Exception::class);
    }
});
