<?php

namespace Database\Factories;

use App\Enums\CandidaturaEstado;
use App\Models\Candidatura;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Candidatura>
 */
class CandidaturaFactory extends Factory
{
    protected $model = Candidatura::class;

    public function definition(): array
    {
        return [
            'vaga_id' => Vaga::factory(),
            'profissional_id' => User::factory()->profissional()->ativo(),
            'estado' => CandidaturaEstado::Pendente,
            'vaga_versao_id' => null,
            'revisao_prazo_em' => null,
        ];
    }
}
