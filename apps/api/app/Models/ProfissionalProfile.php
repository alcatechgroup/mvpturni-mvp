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
        'documento_encrypted',
        'documento_tipo',
        'nivel',
        'score',
        'xp',
        'turnos_realizados',
        'bio',
        'chave_pix_encrypted',
        'dados_bancarios_encrypted',
        'foto_path',
    ];

    protected function casts(): array
    {
        return [
            'dados_bancarios_encrypted' => 'array',
            'score' => 'decimal:2',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
