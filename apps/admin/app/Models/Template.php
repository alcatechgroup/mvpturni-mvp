<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * STORY-020 / ADR-010 — Catálogo de templates contratuais. Dois registros fixos no MVP
 * (`pf_autonomo_eventual`, `mei_pj_b2b`); o `slug` é chave de negócio imutável e o
 * `nome_amigavel` é editável pelo admin. As versões são append-only (ver TemplateVersao).
 */
class Template extends Model
{
    use HasFactory;

    protected $fillable = ['slug', 'nome_amigavel'];

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
