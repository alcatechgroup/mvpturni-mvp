<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * ADR-010 — Aceite eletrônico imutável. Referencia a TemplateVersao exata vigente no
 * momento do aceite; mudanças posteriores no template não o afetam (FK imutável). A
 * imutabilidade é garantida no banco (trigger BEFORE UPDATE/DELETE + REVOKE) — o model
 * é apenas insert-only. `conteudo_renderizado` é autocontido (o documento integral).
 */
class AceiteEletronico extends Model
{
    use HasUuids;

    protected $table = 'aceites_eletronicos';

    /** Imutável: gerencia só `aceito_em`; sem `updated_at`. */
    public const UPDATED_AT = null;

    public const CREATED_AT = null;

    protected $fillable = [
        'template_versao_id',
        'user_id',
        'conteudo_renderizado',
        'dados_renderizados',
        'aceito_em',
        'ip',
        'fingerprint',
    ];

    protected function casts(): array
    {
        return [
            'dados_renderizados' => 'array',
            'aceito_em' => 'datetime',
        ];
    }

    public function templateVersao(): BelongsTo
    {
        return $this->belongsTo(TemplateVersao::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
