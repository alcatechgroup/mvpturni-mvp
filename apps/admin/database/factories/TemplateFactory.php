<?php

namespace Database\Factories;

use App\Models\Template;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Template> */
class TemplateFactory extends Factory
{
    protected $model = Template::class;

    public function definition(): array
    {
        return [
            'slug' => fake()->unique()->slug(2),
            'nome_amigavel' => 'Contrato '.fake()->unique()->word(),
        ];
    }

    public function pf(): static
    {
        return $this->state(['slug' => 'pf_autonomo_eventual', 'nome_amigavel' => 'Contrato PF — Autônomo eventual']);
    }
}
