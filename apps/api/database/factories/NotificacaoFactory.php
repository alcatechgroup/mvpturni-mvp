<?php

namespace Database\Factories;

use App\Enums\NotificacaoTipo;
use App\Models\Notificacao;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Notificacao>
 */
class NotificacaoFactory extends Factory
{
    protected $model = Notificacao::class;

    public function definition(): array
    {
        return [
            'tipo' => NotificacaoTipo::CandidaturaRecebida,
            'destinatario_id' => User::factory(),
            'vaga_id' => Vaga::factory(),
            'candidatura_id' => null,
            'payload' => [],
            'idempotency_key' => (string) Str::uuid(),
            'lida_em' => null,
            'enviada_email_em' => null,
            'falha_envio_em' => null,
            'tentativas_envio' => 0,
            'criada_em' => now(),
        ];
    }

    public function lida(): static
    {
        return $this->state(fn () => ['lida_em' => now()]);
    }

    /** E-mail já enviado (sai da fila implícita do worker). */
    public function emailEnviado(): static
    {
        return $this->state(fn () => ['enviada_email_em' => now()]);
    }

    public function tipo(NotificacaoTipo $tipo): static
    {
        return $this->state(fn () => ['tipo' => $tipo]);
    }
}
