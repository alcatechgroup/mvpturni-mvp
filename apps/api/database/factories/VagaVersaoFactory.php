<?php

namespace Database\Factories;

use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<VagaVersao>
 */
class VagaVersaoFactory extends Factory
{
    protected $model = VagaVersao::class;

    public function definition(): array
    {
        return [
            'vaga_id' => Vaga::factory(),
            'versao' => 1,
            'snapshot' => [
                'funcao_id' => 1,
                'data_inicio' => now()->addDays(3)->toIso8601String(),
                'data_fim' => now()->addDays(3)->addHours(6)->toIso8601String(),
                'valor' => 150.00,
                'posicoes' => 1,
                'observacoes' => null,
                'lat' => -23.55,
                'lng' => -46.63,
            ],
            'editado_por' => null,
        ];
    }
}
