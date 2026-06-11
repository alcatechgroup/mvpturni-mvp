<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * STORY-096 / ADR-020 (Decisão 6) — leitura da trilha GERAL de domínio (`audit_logs`, escrita
 * pela api: `turno.criado`, `turno.checkin_validado`, `turno.checkout_solicitado`,
 * `turno.disputa_aberta`, `turno.disputa_resolvida`...). Distinta do `admin_audit_log` (ações
 * de admin, ADR-009). Append-only no banco real — aqui só leitura (compõe a trilha do caso).
 */
class TurnoAuditLog extends Model
{
    use HasFactory, HasUuids;

    public $timestamps = false;

    protected $table = 'audit_logs';

    protected $fillable = [
        'actor_id', 'action', 'target_type', 'target_id', 'payload', 'ip', 'user_agent', 'created_at',
    ];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
            'created_at' => 'datetime',
        ];
    }
}
