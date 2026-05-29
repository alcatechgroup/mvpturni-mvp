<?php

namespace Database\Factories;

use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<TemplateVersao> */
class TemplateVersaoFactory extends Factory
{
    protected $model = TemplateVersao::class;

    public function definition(): array
    {
        return [
            'template_id' => Template::factory(),
            'versao' => 1,
            'conteudo' => "## Termos gerais\n\nNome: {{profissional.nome}} · CPF: {{profissional.documento}}\n\n## Termos do turno específico\n\nContratante: {{contratante.razao_social}} · Valor: {{turno.valor}}",
            'criado_por_admin_id' => User::factory()->admin(),
            'ativa' => false,
        ];
    }

    public function ativa(): static
    {
        return $this->state(['ativa' => true]);
    }

    public function versao(int $n): static
    {
        return $this->state(['versao' => $n]);
    }
}
