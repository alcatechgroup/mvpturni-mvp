<?php

namespace Database\Factories;

use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ProfissionalProfile>
 *
 * STORY-048 — perfil de profissional para os testes do feed: função primária, geo na
 * Grande SP (mesmo retângulo das vagas de VagaFactory) e raio amplo por padrão, para que
 * as vagas caiam dentro do raio sem ajuste fino.
 */
class ProfissionalProfileFactory extends Factory
{
    protected $model = ProfissionalProfile::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory()->profissional()->ativo(),
            'tipo_pessoa' => 'MEI',
            'cidade' => 'São Paulo',
            'bairro' => 'Centro',
            'funcao_id' => Funcao::factory(),
            'funcoes_secundarias' => [],
            'lat' => -23.55,
            'lng' => -46.63,
            'raio_max_km' => 50,
            'nivel' => 'Elite',
            'score' => 4.8,
            'turnos_realizados' => 80,
        ];
    }

    /** Sem geolocalização declarada (feed não filtra por raio; distância = null). */
    public function semGeo(): static
    {
        return $this->state(fn () => ['lat' => null, 'lng' => null]);
    }

    /** Cold start (CA-9): Iniciante, 0 turnos → histórico e nível zerados. */
    public function coldStart(): static
    {
        return $this->state(fn () => [
            'nivel' => 'Iniciante',
            'score' => 0,
            'turnos_realizados' => 0,
        ]);
    }
}
