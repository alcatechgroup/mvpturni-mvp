<?php

namespace Database\Factories;

use App\Enums\AvaliacaoDirecao;
use App\Enums\TurnoStatus;
use App\Models\Avaliacao;
use App\Models\Turno;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * STORY-085 / ADR-019. Avaliação coerente: nasce de um turno avaliável (finalizado) e deriva
 * autor/avaliado da direção. Por padrão é o contratante avaliando o profissional; use
 * `doProfissional()` para a direção oposta. `paraTurno()` fixa o turno (cenários do motor).
 *
 * @extends Factory<Avaliacao>
 */
class AvaliacaoFactory extends Factory
{
    protected $model = Avaliacao::class;

    public function definition(): array
    {
        $turno = Turno::factory()->status(TurnoStatus::Finalizado);

        return [
            'turno_id' => $turno,
            'direcao' => AvaliacaoDirecao::ContratanteParaProfissional,
            // autor/avaliado derivam do turno já resolvido + da direção corrente.
            'autor_id' => fn (array $attrs) => $this->autorParaDirecao($attrs),
            'avaliado_id' => fn (array $attrs) => $this->avaliadoParaDirecao($attrs),
            'estrelas' => fake()->numberBetween(1, 5),
            'comentario' => fake()->boolean(60) ? fake()->sentence() : null,
        ];
    }

    /** Direção profissional → contratante (o profissional avalia o estabelecimento). */
    public function doProfissional(): static
    {
        return $this->state(fn () => ['direcao' => AvaliacaoDirecao::ProfissionalParaContratante]);
    }

    /** Fixa o turno-alvo (cenários de reputação que precisam de turnos específicos). */
    public function paraTurno(Turno $turno): static
    {
        return $this->state(fn () => ['turno_id' => $turno->id]);
    }

    public function estrelas(int $estrelas): static
    {
        return $this->state(fn () => ['estrelas' => $estrelas]);
    }

    private function autorParaDirecao(array $attrs): string
    {
        $turno = Turno::findOrFail($attrs['turno_id']);

        return $attrs['direcao'] === AvaliacaoDirecao::ContratanteParaProfissional
            ? $turno->contratante_id
            : $turno->profissional_id;
    }

    private function avaliadoParaDirecao(array $attrs): string
    {
        $turno = Turno::findOrFail($attrs['turno_id']);

        return $attrs['direcao'] === AvaliacaoDirecao::ContratanteParaProfissional
            ? $turno->profissional_id
            : $turno->contratante_id;
    }
}
