<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-020 / ADR-010 — Uma versão (append-only) do conteúdo de um template.
 *
 * O `conteudo` é imutável após a criação (trigger no banco); toda edição é uma nova versão.
 * Apenas a coluna `ativa` muda após o INSERT — daí a ausência de `updated_at`.
 */
class TemplateVersao extends Model
{
    use HasFactory;

    protected $table = 'template_versoes';

    /** Append-only: o banco gerencia `created_at`; não existe `updated_at`. */
    public const UPDATED_AT = null;

    protected $fillable = ['template_id', 'versao', 'conteudo', 'criado_por_admin_id', 'ativa'];

    protected function casts(): array
    {
        return [
            'ativa' => 'boolean',
            'versao' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    public function template(): BelongsTo
    {
        return $this->belongsTo(Template::class);
    }

    public function autor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'criado_por_admin_id');
    }
}
