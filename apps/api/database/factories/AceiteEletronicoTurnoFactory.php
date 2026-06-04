<?php

namespace Database\Factories;

use App\Models\AceiteEletronicoTurno;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * STORY-055 / ADR-015 (CA-3). Aceite imutável de turno com TemplateVersao válida de origem.
 *
 * @extends Factory<AceiteEletronicoTurno>
 */
class AceiteEletronicoTurnoFactory extends Factory
{
    protected $model = AceiteEletronicoTurno::class;

    public function definition(): array
    {
        return [
            'turno_id' => Turno::factory(),
            'template_versao_id' => function () {
                $template = Template::create([
                    'slug' => 'pf_autonomo_eventual_'.Str::random(6),
                    'categoria' => 'aceite_turno',
                    'nome_amigavel' => 'Contrato PF — Aceite de Turno',
                ]);

                return TemplateVersao::create([
                    'template_id' => $template->id,
                    'versao' => 1,
                    'conteudo' => 'Contrato eventual de turno. {{turno.funcao}} — {{turno.valor}}.',
                    'criado_por_admin_id' => User::factory()->create(['role' => 'admin', 'status' => 'ativo'])->id,
                    'ativa' => true,
                ])->id;
            },
            'conteudo_renderizado' => 'Contrato eventual de turno. Garçom — R$ 200,00.',
            'dados_renderizados' => [
                'turno.funcao' => 'Garçom',
                'turno.valor' => 'R$ 200,00',
                'habitualidade.override_aceito' => false,
            ],
            'aceito_em' => now(),
            'ip' => fake()->ipv4(),
            'fingerprint' => hash('sha256', fake()->userAgent().':'.fake()->ipv4().':'.now()->toDateString()),
            'habitualidade_override' => false,
        ];
    }

    /** Aceite com cláusula de override de habitualidade (3ª alocação semanal de PJ — PDR-002). */
    public function comOverrideHabitualidade(): static
    {
        return $this->state(fn () => [
            'habitualidade_override' => true,
            'dados_renderizados' => [
                'turno.funcao' => 'Garçom',
                'turno.valor' => 'R$ 200,00',
                'habitualidade.override_aceito' => true,
            ],
        ]);
    }
}
