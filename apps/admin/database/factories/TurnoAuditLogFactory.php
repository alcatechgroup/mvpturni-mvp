<?php

namespace Database\Factories;

use App\Models\TurnoAuditLog;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * STORY-096 — entrada da trilha de auditoria do turno para os testes do Backoffice. No banco
 * real quem escreve é a api (append-only — ADR-013/020).
 *
 * @extends Factory<TurnoAuditLog>
 */
class TurnoAuditLogFactory extends Factory
{
    protected $model = TurnoAuditLog::class;

    public function definition(): array
    {
        return [
            'actor_id' => null,
            'action' => 'turno.criado',
            'target_type' => 'Turno',
            'target_id' => (string) fake()->uuid(),
            'payload' => null,
            'ip' => '127.0.0.1',
            'user_agent' => 'seed',
            'created_at' => now()->subHours(6),
        ];
    }
}
