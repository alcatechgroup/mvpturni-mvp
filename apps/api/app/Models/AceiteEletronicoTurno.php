<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-055 / ADR-015 (CA-3) — Aceite eletrônico imutável POR TURNO (compliance.md). Espelha
 * ADR-010 (aceite de adesão do usuário) mas é tabela separada: carrega placeholders do turno
 * e a cláusula de override de habitualidade (PDR-002). Referencia a TemplateVersao exata
 * vigente no aceite (FK imutável). A imutabilidade é garantida no banco (trigger + REVOKE) —
 * o model é apenas insert-only. `conteudo_renderizado` é autocontido (documento integral).
 */
class AceiteEletronicoTurno extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'aceites_eletronicos_turno';

    /** Imutável: gerencia só `aceito_em`; sem created_at/updated_at. */
    public const UPDATED_AT = null;

    public const CREATED_AT = null;

    protected $fillable = [
        'turno_id',
        'template_versao_id',
        'conteudo_renderizado',
        'dados_renderizados',
        'aceito_em',
        'ip',
        'fingerprint',
        'habitualidade_override',
    ];

    protected function casts(): array
    {
        return [
            'dados_renderizados' => 'array',
            'aceito_em' => 'datetime',
            'habitualidade_override' => 'boolean',
        ];
    }

    public function turno(): BelongsTo
    {
        return $this->belongsTo(Turno::class);
    }

    public function templateVersao(): BelongsTo
    {
        return $this->belongsTo(TemplateVersao::class);
    }
}
