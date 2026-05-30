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
use Turni\Domain\Email\EmailTransacional;
use Turni\Domain\Email\EnviarEmailTransacionalJob;
use Turni\Domain\Email\TipoEmail;

#[Fillable(['name', 'email', 'password', 'role', 'status', 'aprovado_em', 'welcome_seen_at', 'cadastro_completed_at'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

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

    /**
     * Roteia a recuperação de senha do Fortify pela ACL de e-mail (STORY-021 CA-6 /
     * ADR-011 §b) em vez da notification padrão do Laravel: o e-mail `recuperacao_senha`
     * passa pela fila e usa o template DDR-001. O link aponta para a tela de redefinição
     * do WebApp com o token assinado (TTL de auth.passwords — 60 min, ADR-007 §f).
     *
     * @param  string  $token
     */
    public function sendPasswordResetNotification($token): void
    {
        $base = rtrim((string) config('app.webapp_url', config('app.url')), '/');
        $url = $base.'/reset-password?token='.$token.'&email='.urlencode($this->email);

        EnviarEmailTransacionalJob::dispatch(new EmailTransacional(
            destinatario: $this->email,
            tipo: TipoEmail::RecuperacaoSenha,
            dados: [
                'nome' => $this->name,
                'link_redefinicao' => $url,
                'expiracao_minutos' => (int) config('auth.passwords.users.expire', 60),
            ],
        ));
    }
}
