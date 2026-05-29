<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ContratanteProfile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'cnpj_encrypted',
        'nome_estabelecimento',
        'tipo_operacao',
        'telefone',
        'cidade',
        'endereco_completo',
        'plano',
        'logo_path',
        'foto_path',
        'termos_aceitos_at',
    ];

    protected function casts(): array
    {
        return [
            'termos_aceitos_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
