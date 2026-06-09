<?php

namespace Database\Factories;

use App\Models\ContratanteProfile;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * STORY-085 — perfil de contratante para os testes de reputação (score recíproco) e perfil
 * público. Mínimo coerente: estabelecimento nomeado e operação. Score parte de 0 (recalculado
 * pelo MotorReputacao a cada avaliação recebida).
 *
 * @extends Factory<ContratanteProfile>
 */
class ContratanteProfileFactory extends Factory
{
    protected $model = ContratanteProfile::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory()->contratante()->ativo(),
            'nome_estabelecimento' => fake()->company(),
            'tipo_operacao' => 'restaurante',
            'cidade' => 'São Paulo',
            'score' => 0,
        ];
    }
}
