<?php

namespace App\Models;

use App\Enums\AvaliacaoDirecao;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-085 / ADR-019 Decisão 1. Avaliação recíproca — uma linha por direção/turno
 * (`UNIQUE (turno_id, direcao)`). `autor_id`/`avaliado_id` são deriváveis de turno+direção,
 * mas materializados porque toda consulta de reputação parte de "avaliações recebidas por X"
 * (ADR-019). Mutável no MVP (sem trigger de imutabilidade — não é prova jurídica como o
 * aceite; moderação é admin caso-a-caso).
 */
class Avaliacao extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'avaliacoes';

    protected $fillable = [
        'turno_id', 'autor_id', 'avaliado_id', 'direcao', 'estrelas', 'comentario',
    ];

    protected function casts(): array
    {
        return [
            'direcao' => AvaliacaoDirecao::class,
            'estrelas' => 'integer',
        ];
    }

    public function turno(): BelongsTo
    {
        return $this->belongsTo(Turno::class);
    }

    public function autor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'autor_id');
    }

    public function avaliado(): BelongsTo
    {
        return $this->belongsTo(User::class, 'avaliado_id');
    }
}
