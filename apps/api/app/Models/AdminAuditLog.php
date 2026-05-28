<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminAuditLog extends Model
{
    // Append-only: sem updated_at e sem possibilidade de update/delete
    public $timestamps = false;

    protected $table = 'admin_audit_log';

    protected $fillable = [
        'actor_id',
        'action',
        'target_type',
        'target_id',
        'payload',
        'ip',
        'user_agent',
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
