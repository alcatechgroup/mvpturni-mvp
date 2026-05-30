<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Registro de um lembrete de completar cadastro enviado a um usuário (STORY-021 CA-5).
 * Unicidade (user_id, numero) na migração garante idempotência do scheduler.
 */
class CadastroLembrete extends Model
{
    protected $table = 'cadastro_lembretes';

    protected $fillable = ['user_id', 'numero', 'enviado_em'];

    protected function casts(): array
    {
        return [
            'numero' => 'integer',
            'enviado_em' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
