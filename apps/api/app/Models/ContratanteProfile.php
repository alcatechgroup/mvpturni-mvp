<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ContratanteProfile extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'user_id',
        'cnpj_encrypted',
        'cnpj_hash',
        'nome_estabelecimento',
        'tipo_operacao',
        'telefone',
        'cidade',
        'endereco_completo',
        'logradouro',
        'numero',
        'bairro',
        'uf',
        'cep',
        'complemento',
        // Coordenadas do estabelecimento (referência do geofencing — PDR-008). Populadas pela
        // STORY-074 (geocoding do endereço); nulas por ora.
        'lat',
        'lng',
        'apelido_estabelecimento',
        'segmento',
        'ano_fundacao',
        'qtd_funcionarios',
        'turnos_operacao',
        'cultura_valores',
        'site',
        'redes_sociais',
        'contatos_adicionais',
        'plano',
        'logo_path',
        'foto_path',
        'termos_aceitos_at',
    ];

    protected function casts(): array
    {
        return [
            // Criptografia em repouso do CNPJ (ADR-009 Decisão 5A) — query direta no
            // Postgres não retorna texto claro (CA-6). Unicidade via cnpj_hash (IDR-022 d).
            'cnpj_encrypted' => 'encrypted',
            'lat' => 'decimal:7',
            'lng' => 'decimal:7',
            'ano_fundacao' => 'integer',
            'redes_sociais' => 'array',
            'contatos_adicionais' => 'array',
            'termos_aceitos_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
