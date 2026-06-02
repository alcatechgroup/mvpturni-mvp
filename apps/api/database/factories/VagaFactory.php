<?php

namespace Database\Factories;

use App\Enums\VagaEstado;
use App\Models\Funcao;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Vaga>
 */
class VagaFactory extends Factory
{
    protected $model = Vaga::class;

    public function definition(): array
    {
        $inicio = fake()->dateTimeBetween('+1 day', '+20 days');
        $fim = (clone $inicio)->modify('+6 hours');

        return [
            'contratante_id' => User::factory()->contratante()->ativo(),
            'funcao_id' => Funcao::factory(),
            'data_inicio' => $inicio,
            'data_fim' => $fim,
            'valor' => fake()->randomFloat(2, 80, 400),
            'valor_hora' => null,
            'posicoes' => 1,
            'posicoes_preenchidas' => 0,
            'observacoes' => fake()->optional()->sentence(),
            // Região da Grande São Paulo (para os testes de bounding-box do feed).
            'lat' => fake()->randomFloat(7, -23.70, -23.45),
            'lng' => fake()->randomFloat(7, -46.80, -46.45),
            'cidade' => 'São Paulo',
            'uf' => 'SP',
            'estado' => VagaEstado::Aberta,
            'versao_atual' => 1,
            'publicada_em' => now(),
        ];
    }

    public function fechada(): static
    {
        return $this->state(fn () => [
            'estado' => VagaEstado::Fechada,
            'posicoes' => 1,
            'posicoes_preenchidas' => 1,
            'fechada_em' => now(),
        ]);
    }

    public function cancelada(): static
    {
        return $this->state(fn () => [
            'estado' => VagaEstado::Cancelada,
            'cancelada_em' => now(),
        ]);
    }
}
