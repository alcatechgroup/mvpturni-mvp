<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/** Função pretendida pelo profissional (STORY-017 — tabela auxiliar com seed). */
class Funcao extends Model
{
    use HasFactory;

    protected $table = 'funcoes';

    protected $fillable = ['slug', 'nome', 'ativo'];

    protected function casts(): array
    {
        return ['ativo' => 'boolean'];
    }
}
