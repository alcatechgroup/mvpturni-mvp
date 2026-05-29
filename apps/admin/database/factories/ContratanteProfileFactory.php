<?php

namespace Database\Factories;

use App\Models\ContratanteProfile;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ContratanteProfile>
 */
class ContratanteProfileFactory extends Factory
{
    protected $model = ContratanteProfile::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory()->contratante(),
            'nome_estabelecimento' => fake()->company(),
            'tipo_operacao' => fake()->randomElement(['Restaurante', 'Hotel', 'Bar', 'Eventos']),
            'telefone' => fake()->numerify('(11) 3 ####-####'),
            'cidade' => fake()->city(),
            'termos_aceitos_at' => now(),
            'foto_path' => null,
        ];
    }
}
