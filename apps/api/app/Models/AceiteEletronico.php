<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-023 / ADR-010 Decisão 4 — Aceite eletrônico imutável.
 *
 * Evidência jurídica do que foi exibido e aceito pelo usuário. Imutável após criação,
 * garantido no banco (trigger BEFORE UPDATE OR DELETE + REVOKE no role de runtime) — qualquer
 * tentativa de UPDATE/DELETE lança exceção. `conteudo_renderizado` é autocontido: reproduz o
 * documento integral mesmo se o template/versão forem apagados.
 */
class AceiteEletronico extends Model
{
    protected $table = 'aceites_eletronicos';

    /** Imutável: sem timestamps padrão; o banco preenche `aceito_em` no INSERT. */
    public $timestamps = false;

    protected $fillable = [
        'template_versao_id',
        'user_id',
        'conteudo_renderizado',
        'dados_renderizados',
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
