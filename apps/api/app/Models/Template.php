<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * ADR-010 — Catálogo de templates contratuais (lado api). Leitura: a edição vive no
 * Backoffice (app admin, STORY-020). Dois slugs fixos: `pf_autonomo_eventual`, `mei_pj_b2b`.
 */
class Template extends Model
{
    use HasUuids;

    protected $fillable = ['slug', 'categoria', 'nome_amigavel'];

    /** @return HasMany<TemplateVersao> */
    public function versoes(): HasMany
    {
        return $this->hasMany(TemplateVersao::class)->orderByDesc('versao');
    }

    /** Versão atualmente ativa (no máximo uma — partial unique index garante). */
    public function versaoAtiva(): HasOne
    {
        return $this->hasOne(TemplateVersao::class)->where('ativa', true);
    }
}
