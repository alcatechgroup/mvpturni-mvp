<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-044 / ADR-013 Decisão 1. Snapshot append-only de uma versão material da vaga
 * (PDR-009). Imutabilidade garantida no banco (trigger BEFORE UPDATE/DELETE + REVOKE),
 * mesmo padrão da AceiteEletronico/ADR-010 — o model é só insert-only. `created_at` tem
 * default NOW() no banco; sem `updated_at`.
 */
class VagaVersao extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'vaga_versoes';

    public $timestamps = false;

    protected $fillable = ['vaga_id', 'versao', 'snapshot', 'editado_por'];

    protected function casts(): array
    {
        return [
            'snapshot' => 'array',
            'versao' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    public function vaga(): BelongsTo
    {
        return $this->belongsTo(Vaga::class);
    }

    public function editadoPor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'editado_por');
    }
}
