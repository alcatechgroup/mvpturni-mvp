<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;

/**
 * STORY-056 / ADR-016 (CA-6). Registro de deduplicação de um webhook entrante do Pagar.me.
 * `event_id` único: a 1ª recepção processa; as repetições respondem 200 sem reprocessar.
 */
class WebhookEventoPagarme extends Model
{
    use HasUuids;

    protected $table = 'webhook_eventos_pagarme';

    public $timestamps = false;

    protected $fillable = ['event_id', 'tipo', 'turno_id', 'payload', 'recebido_em', 'processado_em'];

    protected function casts(): array
    {
        return [
            'payload' => 'array',
            'recebido_em' => 'datetime',
            'processado_em' => 'datetime',
        ];
    }
}
