<?php

// STORY-016 — CA-15 — Imutabilidade do audit log via trigger + REVOKE

use App\Models\AdminAuditLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

test('audit log pode ser criado (INSERT funciona)', function () {
    $admin = User::factory()->admin()->create();

    $entry = AdminAuditLog::create([
        'actor_id' => $admin->id,
        'action' => 'admin.login',
        'target_type' => null,
        'target_id' => null,
        'payload' => ['email' => $admin->email],
        'ip' => '127.0.0.1',
        'user_agent' => 'Test',
    ]);

    expect($entry->id)->toBeInt()->toBeGreaterThan(0);
});

test('audit log é imutável — UPDATE lança exceção do banco (trigger)', function () {
    $admin = User::factory()->admin()->create();

    $entry = AdminAuditLog::create([
        'actor_id' => $admin->id,
        'action' => 'admin.login',
        'payload' => ['email' => $admin->email],
        'ip' => '127.0.0.1',
        'user_agent' => 'Test',
    ]);

    expect(function () use ($entry) {
        DB::statement('UPDATE admin_audit_log SET action = ? WHERE id = ?', ['hacked', $entry->id]);
    })->toThrow(Exception::class);
});

test('audit log é imutável — DELETE lança exceção do banco (trigger)', function () {
    $admin = User::factory()->admin()->create();

    $entry = AdminAuditLog::create([
        'actor_id' => $admin->id,
        'action' => 'admin.login',
        'payload' => ['email' => $admin->email],
        'ip' => '127.0.0.1',
        'user_agent' => 'Test',
    ]);

    expect(function () use ($entry) {
        DB::statement('DELETE FROM admin_audit_log WHERE id = ?', [$entry->id]);
    })->toThrow(Exception::class);
});

test('audit log — Eloquent update() lança exceção', function () {
    $admin = User::factory()->admin()->create();

    $entry = AdminAuditLog::create([
        'actor_id' => $admin->id,
        'action' => 'admin.login',
        'payload' => ['email' => $admin->email],
        'ip' => '127.0.0.1',
        'user_agent' => 'Test',
    ]);

    expect(function () use ($entry) {
        $entry->update(['action' => 'hacked']);
    })->toThrow(Exception::class);
});

test('audit log — Eloquent delete() lança exceção', function () {
    $admin = User::factory()->admin()->create();

    $entry = AdminAuditLog::create([
        'actor_id' => $admin->id,
        'action' => 'admin.login',
        'payload' => ['email' => $admin->email],
        'ip' => '127.0.0.1',
        'user_agent' => 'Test',
    ]);

    expect(function () use ($entry) {
        $entry->delete();
    })->toThrow(Exception::class);
});
