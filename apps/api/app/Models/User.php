<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'password', 'role', 'status', 'welcome_seen_at', 'cadastro_completed_at'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
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

    public function isAtivo(): bool
    {
        return $this->status === 'ativo';
    }

    public function isLiberado(): bool
    {
        return $this->status === 'liberado';
    }

    public function isPendente(): bool
    {
        return $this->status === 'pendente_aprovacao';
    }

    /** Determina o estado do funil para o funnel guard. */
    public function funnelState(): string
    {
        return match (true) {
            $this->status === 'pendente_aprovacao' => 'await_approval',
            $this->status === 'recusado' => 'rejected',
            $this->status === 'liberado' && $this->welcome_seen_at === null => 'await_welcome',
            $this->status === 'liberado' && $this->cadastro_completed_at === null => 'await_cadastro',
            default => 'active',
        };
    }

    public function canAccessWebApp(): bool
    {
        return in_array($this->role, ['contratante', 'profissional'], true);
    }
}
