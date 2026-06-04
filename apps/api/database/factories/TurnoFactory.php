<?php

namespace Database\Factories;

use App\Enums\CandidaturaEstado;
use App\Enums\TurnoStatus;
use App\Models\Candidatura;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * STORY-055 / ADR-015. Turno coerente: financeiro consistente (total = valor + taxa, 15% MVP)
 * e estabelecimento = contratante (convenção MVP). Cria a candidatura aprovada de origem.
 *
 * @extends Factory<Turno>
 */
class TurnoFactory extends Factory
{
    protected $model = Turno::class;

    public function definition(): array
    {
        $valor = fake()->randomFloat(2, 80, 400);
        $taxa = round($valor * 0.15, 2);
        $inicio = fake()->dateTimeBetween('+1 day', '+15 days');
        $fim = (clone $inicio)->modify('+6 hours');

        return [
            'candidatura_id' => Candidatura::factory()->state([
                'estado' => CandidaturaEstado::Aprovada,
                'aprovada_em' => now(),
            ]),
            'vaga_id' => Vaga::factory(),
            'vaga_versao_id' => null,
            'profissional_id' => User::factory()->profissional()->ativo(),
            'contratante_id' => User::factory()->contratante()->ativo(),
            // estabelecimento = contratante no MVP (sem entidade Estabelecimento separada).
            'estabelecimento_id' => fn (array $attrs) => $attrs['contratante_id'],
            'status' => TurnoStatus::Confirmado,
            'valor' => $valor,
            'taxa_turni' => $taxa,
            'total_contratante' => round($valor + $taxa, 2),
            'data_inicio' => $inicio,
            'data_fim' => $fim,
        ];
    }

    /** Cria o turno diretamente em `$status` (INSERT — o trigger só guarda UPDATE/transição). */
    public function status(TurnoStatus $status): static
    {
        return $this->state(fn () => [
            'status' => $status,
            // Carimba timestamps coerentes com estados pós-check-in/out.
            'check_in_at' => in_array($status, [
                TurnoStatus::Ativo, TurnoStatus::AguardandoCheckout, TurnoStatus::EmDisputa,
                TurnoStatus::Finalizado, TurnoStatus::FinalizadoAjustado,
                TurnoStatus::DisputaResolvidaSemPagamento,
            ], true) ? now()->subHours(3) : null,
            'check_out_at' => in_array($status, [
                TurnoStatus::Finalizado, TurnoStatus::FinalizadoAjustado,
            ], true) ? now() : null,
            'cancelamento' => in_array($status, [TurnoStatus::CanceladoPro, TurnoStatus::CanceladoEmp], true)
                ? [
                    'lado' => $status === TurnoStatus::CanceladoPro ? 'pro' : 'emp',
                    'motivo' => null,
                    'antecedencia_horas' => 12,
                    'em' => now()->toIso8601String(),
                ]
                : null,
        ]);
    }
}
