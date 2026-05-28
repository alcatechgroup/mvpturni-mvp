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
        'endereco_completo',
        'plano',
        'logo_path',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
