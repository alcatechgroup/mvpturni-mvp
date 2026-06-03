<?php

namespace App\Models;

use App\Enums\NotificacaoTipo;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * STORY-053 — Notificação in-app + fila implícita de e-mail (CA-1).
 *
 * Criada pelos listeners dos eventos de domínio (CA-2/3/4) e pelos hooks de confirmação/
 * retirada após edição (templates 4/5). Lida pelo WebApp via `GET /api/notificacoes` (CA-7) e
 * pelo worker de e-mail via a fila implícita `enviada_email_em IS NULL` (CA-5).
 *
 * `criada_em` é o timestamp de criação (nomeado pela estória); não há created_at/updated_at do
 * Eloquent — só `lida_em`/`enviada_email_em`/`falha_envio_em`/`tentativas_envio` mudam após o INSERT.
 */
class Notificacao extends Model
{
    use HasFactory, HasUuids;

    public $timestamps = false;

    protected $table = 'notificacoes';

    protected $fillable = [
        'tipo', 'destinatario_id', 'vaga_id', 'candidatura_id', 'payload',
        'idempotency_key', 'lida_em', 'enviada_email_em', 'falha_envio_em', 'tentativas_envio',
        'criada_em',
    ];

    protected function casts(): array
    {
        return [
            'tipo' => NotificacaoTipo::class,
            'payload' => 'array',
            'lida_em' => 'datetime',
            'enviada_email_em' => 'datetime',
            'falha_envio_em' => 'datetime',
            'tentativas_envio' => 'integer',
            'criada_em' => 'datetime',
        ];
    }

    /** Caixa do destinatário (CA-7): mais recentes primeiro. */
    public function scopeDoDestinatario(Builder $query, string $userId): Builder
    {
        return $query->where('destinatario_id', $userId)->orderByDesc('criada_em');
    }

    /** Não-lidas (CA-7 `?lidas=false` + contagem do badge). */
    public function scopeNaoLidas(Builder $query): Builder
    {
        return $query->whereNull('lida_em');
    }

    /** Fila implícita do worker de e-mail (CA-5): pendentes, sem falha definitiva. */
    public function scopePendentesDeEmail(Builder $query): Builder
    {
        return $query->whereNull('enviada_email_em')->whereNull('falha_envio_em')->orderBy('criada_em');
    }

    public function destinatario(): BelongsTo
    {
        return $this->belongsTo(User::class, 'destinatario_id');
    }

    public function vaga(): BelongsTo
    {
        return $this->belongsTo(Vaga::class);
    }

    public function candidatura(): BelongsTo
    {
        return $this->belongsTo(Candidatura::class);
    }
}
