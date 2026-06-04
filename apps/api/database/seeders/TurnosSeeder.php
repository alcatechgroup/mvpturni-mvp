<?php

namespace Database\Seeders;

use App\Enums\TurnoStatus;
use App\Models\AceiteEletronicoTurno;
use App\Models\Turno;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-055 / ADR-015 (CA-7) — seed dos 11 estados do Turno em ambiente local. A partir
 * daqui, as próximas estórias do EPIC-003 seedam cenários sem reimplementar a montagem.
 *
 * Coerência: um único contratante (= estabelecimento, convenção MVP) e um único profissional
 * compartilhados pelos 11 turnos — útil também para exercitar habitualidade (PDR-002). Cada
 * turno recebe um AceiteEletronicoTurno imutável (o `confirmado` com override de habitualidade
 * para demonstrar a cláusula PJ — compliance.md). Idempotente: não recria se já houver turnos
 * do contratante seed. Os turnos são inseridos diretamente no estado-alvo (INSERT; o trigger
 * só guarda transições de UPDATE).
 */
class TurnosSeeder extends Seeder
{
    public function run(): void
    {
        $contratante = User::updateOrCreate(
            ['email' => 'contratante.turnos.seed@turni.local'],
            [
                'name' => 'Estabelecimento Turnos Seed',
                'password' => Hash::make('password'),
                'role' => 'contratante',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        $profissional = User::updateOrCreate(
            ['email' => 'profissional.turnos.seed@turni.local'],
            [
                'name' => 'Profissional Turnos Seed',
                'password' => Hash::make('password'),
                'role' => 'profissional',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        // Idempotência: se o contratante seed já tem turnos, não recria.
        if (Turno::where('contratante_id', $contratante->id)->exists()) {
            return;
        }

        foreach (TurnoStatus::cases() as $status) {
            $turno = Turno::factory()->status($status)->create([
                'contratante_id' => $contratante->id,
                'estabelecimento_id' => $contratante->id,
                'profissional_id' => $profissional->id,
            ]);

            // Todo turno nasce com aceite imutável; o `confirmado` demonstra o override PJ.
            $aceite = AceiteEletronicoTurno::factory();
            if ($status === TurnoStatus::Confirmado) {
                $aceite = $aceite->comOverrideHabitualidade();
            }
            $aceite->create(['turno_id' => $turno->id]);
        }

        $this->command?->info('TurnosSeeder: 11 turnos (um por estado) + aceites criados.');
    }
}
