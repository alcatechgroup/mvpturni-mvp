<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProfissionalProfile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'tipo_pessoa',
        'telefone',
        'cidade',
        'bairro',
        'funcao_id',
        'funcoes_secundarias',
        'termos_aceitos_at',
        'documento_encrypted',
        'documento_tipo',
        'documento_hash',
        'nivel',
        'score',
        'xp',
        'turnos_realizados',
        'bio',
        'raio_max_km',
        'preco_hora',
        'chave_pix_encrypted',
        'dados_bancarios_encrypted',
        'foto_path',
        'documentos_comprobatorios',
    ];

    protected function casts(): array
    {
        return [
            // Criptografia em repouso (ADR-009 Decisão 5A) — query direta no Postgres
            // não retorna texto claro (CA-6).
            'documento_encrypted' => 'encrypted',
            'chave_pix_encrypted' => 'encrypted',
            'dados_bancarios_encrypted' => 'array',
            'funcoes_secundarias' => 'array',
            'documentos_comprobatorios' => 'array',
            'score' => 'decimal:2',
            'preco_hora' => 'decimal:2',
            'raio_max_km' => 'integer',
            'termos_aceitos_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function funcao(): BelongsTo
    {
        return $this->belongsTo(Funcao::class);
    }
}
