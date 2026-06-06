<?php

namespace App\Models;

use App\Casts\ChavePixCompartilhada;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-065 (CA-5, CA-8) — caso da fila "Pix com falha" (lado Backoffice). A api escreve
 * (worker, no instante da falha — snapshot operacional + chave cifrada IDR-028); o admin
 * lista e RESOLVE (nota obrigatória + autor + timestamp, auditado em admin_audit_log).
 */
class PixFalha extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'pix_falhas';

    protected $fillable = [
        'turno_id', 'tipo', 'profissional_nome', 'funcao', 'estabelecimento', 'valor',
        'chave_pix', 'razao', 'payload_gateway', 'falhou_em',
        'resolvido_em', 'resolvido_por', 'nota_resolucao',
    ];

    protected function casts(): array
    {
        return [
            'chave_pix' => ChavePixCompartilhada::class,
            'valor' => 'decimal:2',
            'payload_gateway' => 'array',
            'falhou_em' => 'datetime',
            'resolvido_em' => 'datetime',
        ];
    }

    public function resolvidoPor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'resolvido_por');
    }

    public function scopePendentes(Builder $query): Builder
    {
        return $query->whereNull('resolvido_em');
    }
}
