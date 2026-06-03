<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-044 / ADR-013 Decisão 5. Trilha de auditoria GERAL de eventos de domínio
 * (ator = qualquer usuário: contratante/profissional). Distinta do admin_audit_log
 * (ações de admin, ADR-009). Append-only: imutável no banco (trigger + REVOKE).
 */
class AuditLog extends Model
{
    use HasUuids;

    // Append-only: sem updated_at; created_at tem default NOW() no banco.
    public $timestamps = false;

    protected $table = 'audit_logs';

    protected $fillable = [
        'actor_id', 'action', 'target_type', 'target_id', 'payload', 'ip', 'user_agent',
    ];

    protected $casts = [
        'payload' => 'array',
        'created_at' => 'datetime',
    ];

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }
}
