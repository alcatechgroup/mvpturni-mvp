<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * ADR-010 — Uma versão (append-only) do conteúdo de um template. `conteudo` é imutável
 * (trigger no banco); só `ativa` muda após o INSERT — daí a ausência de `updated_at`.
 */
class TemplateVersao extends Model
{
    protected $table = 'template_versoes';

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
}
