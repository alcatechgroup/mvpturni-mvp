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
        'funcoes_secundarias',
        'chave_pix_encrypted',
        'dados_bancarios_encrypted',
        'documento_comprobatorio_path',
        'foto_path',
    ];

    protected function casts(): array
    {
        return [
            // Criptografia em repouso (ADR-009 Decisão 5 / CA-6): query direta no Postgres
            // devolve ciphertext opaco; o ORM decripta transparente na leitura.
            'documento_encrypted' => 'encrypted',
            'chave_pix_encrypted' => 'encrypted',
            'dados_bancarios_encrypted' => 'array',
            'funcoes_secundarias' => 'array',
            'raio_max_km' => 'integer',
            'preco_hora' => 'decimal:2',
            'score' => 'decimal:2',
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
