<?php

namespace Database\Factories;

use App\Models\Funcao;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Funcao>
 */
class FuncaoFactory extends Factory
{
    protected $model = Funcao::class;

    public function definition(): array
    {
        $nome = fake()->unique()->jobTitle();

        return [
            'slug' => Str::slug($nome).'-'.fake()->unique()->numberBetween(1, 999999),
            'nome' => $nome,
            'ativo' => true,
        ];
    }
}
