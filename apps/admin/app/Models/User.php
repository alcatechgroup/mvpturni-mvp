<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

#[Fillable(['name', 'email', 'password', 'role', 'status', 'aprovado_em', 'welcome_seen_at', 'cadastro_completed_at'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable;

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'aprovado_em' => 'datetime',
            'welcome_seen_at' => 'datetime',
            'cadastro_completed_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function profissionalProfile(): HasOne
    {
        return $this->hasOne(ProfissionalProfile::class);
    }

    public function contratanteProfile(): HasOne
    {
        return $this->hasOne(ContratanteProfile::class);
    }

    public function isAdmin(): bool
    {
        return $this->role === 'admin';
    }

    public function isProfissional(): bool
    {
        return $this->role === 'profissional';
    }

    public function isContratante(): bool
    {
        return $this->role === 'contratante';
    }

    public function isPendente(): bool
    {
        return $this->status === 'pendente_aprovacao';
    }

    /** Perfil específico do papel, ou null para admin (que não tem perfil — ADR-009). */
    public function profile(): ?Model
    {
        return match ($this->role) {
            'profissional' => $this->profissionalProfile,
            'contratante' => $this->contratanteProfile,
            default => null,
        };
    }

    /** Fila de aprovação: pendentes em FIFO (mais antigo primeiro — CA-2). */
    public function scopePendentesFifo(Builder $query): Builder
    {
        return $query->where('status', 'pendente_aprovacao')
            ->orderBy('created_at');
    }
}
