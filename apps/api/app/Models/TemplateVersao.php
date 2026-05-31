<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * STORY-023 / ADR-010 — Uma versão (append-only) do conteúdo de um template.
 *
 * Imutável após criação (trigger no banco); apenas `ativa` muda — daí a ausência de
 * `updated_at`. O aceite eletrônico referencia a versão exata vigente no momento do clique.
 */
class TemplateVersao extends Model
{
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

    /** @return HasMany<AceiteEletronico> */
    public function aceites(): HasMany
    {
        return $this->hasMany(AceiteEletronico::class);
    }
}
