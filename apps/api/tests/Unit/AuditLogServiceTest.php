<?php

// STORY-016 — CA-15 — AuditLogService (núcleo de escrita no audit log)

use App\Models\AdminAuditLog;
use App\Models\User;
use App\Services\AuditLogService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;

uses(RefreshDatabase::class);

test('AuditLogService cria entrada no audit log com campos corretos', function () {
    $admin = User::factory()->admin()->create();

    $request = Request::create('/login', 'POST');
    $service = new AuditLogService($request);

    $service->log('admin.login', $admin->id, null, null, ['email' => $admin->email]);

    $log = AdminAuditLog::first();
    expect($log)->not->toBeNull();
    expect($log->action)->toBe('admin.login');
    expect($log->actor_id)->toBe($admin->id);
    expect($log->payload['email'])->toBe($admin->email);
});

test('AuditLogService cria entrada com actor_id nulo para tentativas sem usuário', function () {
    $request = Request::create('/login', 'POST');
    $service = new AuditLogService($request);

    $service->log('admin.login_failed', null, null, null, ['email' => 'x@y.com']);

    $log = AdminAuditLog::first();
    expect($log->actor_id)->toBeNull();
    expect($log->action)->toBe('admin.login_failed');
});

test('AuditLogService persiste IP e user_agent da requisição', function () {
    $admin = User::factory()->admin()->create();

    $request = Request::create('/login', 'POST', [], [], [], [
        'REMOTE_ADDR' => '192.168.1.1',
        'HTTP_USER_AGENT' => 'TestBrowser/1.0',
    ]);
    $service = new AuditLogService($request);

    $service->log('admin.login', $admin->id);

    $log = AdminAuditLog::first();
    expect($log->ip)->toBe('192.168.1.1');
    expect($log->user_agent)->toBe('TestBrowser/1.0');
});
