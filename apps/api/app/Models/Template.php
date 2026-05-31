<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * STORY-023 / ADR-010 — Catálogo de templates contratuais (leitura no `api`).
 *
 * Espelha o model de `apps/admin` (models são duplicados por app — mesmo padrão de User/Funcao).
 * No `api` o template é apenas LIDO: o completar-cadastro seleciona a versão ativa do slug
 * correto (`pf_autonomo_eventual` se PF; `mei_pj_b2b` se MEI/PJ) para renderizar o aceite.
 */
class Template extends Model
{
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
