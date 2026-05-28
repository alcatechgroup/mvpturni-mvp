<?php

namespace App\Services;

use App\Models\AdminAuditLog;
use Illuminate\Http\Request;

/** Grava eventos auditáveis do admin na tabela append-only (ADR-009 Decisão 4A). */
class AuditLogService
{
    public function __construct(private readonly Request $request) {}

    public function log(
        string $action,
        ?int $actorId = null,
        ?string $targetType = null,
        ?int $targetId = null,
        array $payload = [],
    ): void {
        AdminAuditLog::create([
            'actor_id' => $actorId,
            'action' => $action,
            'target_type' => $targetType,
            'target_id' => $targetId,
            'payload' => $payload ?: null,
            'ip' => $this->request->ip(),
            'user_agent' => $this->request->userAgent(),
        ]);
    }
}
