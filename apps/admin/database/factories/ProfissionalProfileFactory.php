<?php

namespace Database\Factories;

use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ProfissionalProfile>
 */
class ProfissionalProfileFactory extends Factory
{
    protected $model = ProfissionalProfile::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory()->profissional(),
            'tipo_pessoa' => fake()->randomElement(['PF', 'MEI', 'PJ']),
            'telefone' => fake()->numerify('(11) 9 ####-####'),
            'cidade' => fake()->city(),
            'bairro' => fake()->streetName(),
            'funcao_id' => Funcao::factory(),
            'termos_aceitos_at' => now(),
            'foto_path' => null,
        ];
    }

    public function tipo(string $tipoPessoa): static
    {
        return $this->state(fn () => ['tipo_pessoa' => $tipoPessoa]);
    }
}
