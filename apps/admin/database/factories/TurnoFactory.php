<?php

namespace Database\Factories;

use App\Models\Turno;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * STORY-096 — turno para os testes da fila de disputa do Backoffice. No banco real quem
 * escreve/transita é o app `api` (ADR-015/020); aqui é réplica de teste (status string).
 *
 * @extends Factory<Turno>
 */
class TurnoFactory extends Factory
{
    protected $model = Turno::class;

    public function definition(): array
    {
        $valor = fake()->randomFloat(2, 80, 400);
        $inicio = now()->subHours(6);

        return [
            'contratante_id' => User::factory()->contratante(),
            'profissional_id' => User::factory()->profissional(),
            'status' => 'finalizado',
            'valor' => $valor,
            'data_inicio' => $inicio,
            'data_fim' => (clone $inicio)->addHours(6),
            'check_in_at' => (clone $inicio)->addMinutes(2),
            'check_out_at' => null,
            'geofencing_check_in' => ['ok' => true, 'distancia_metros' => 8],
            'geofencing_check_out' => ['ok' => true, 'distancia_metros' => 12],
            'disputa' => null,
            'vaga_versao_id' => null,
        ];
    }

    /** Turno em disputa aberta há `$abertaHaMin` minutos (alimenta a fila + o SLA). */
    public function emDisputa(int $abertaHaMin = 10, string $justificativa = 'O profissional saiu antes do fim combinado e não terminou a limpeza do salão.'): static
    {
        return $this->state(fn () => [
            'status' => Turno::STATUS_EM_DISPUTA,
            'check_out_at' => null,
            'disputa' => [
                'aberta_em' => now()->subMinutes($abertaHaMin)->toIso8601String(),
                'aberta_por' => (string) fake()->uuid(),
                'justificativa_contratante' => $justificativa,
                'resolucao' => null,
                'nota_admin' => null,
                'resolvida_em' => null,
                'resolvida_por' => null,
            ],
        ]);
    }
}
