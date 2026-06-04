<?php

namespace Database\Seeders;

use App\Enums\CandidaturaEstado;
use App\Enums\TurnoStatus;
use App\Enums\VagaEstado;
use App\Models\Candidatura;
use App\Models\Funcao;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-057 / ADR-017 (CA-5) — seed da PoC do cronômetro bilateral em homolog. NÃO entra no
 * DatabaseSeeder (é uma demonstração de spike); roda à mão:
 *
 *     php artisan db:seed --class=Database\\Seeders\\CronometroPocSeeder --force
 *
 * Cria (idempotente, production-safe — sem factories/fake()) um par de usuários funnel-ativos e um
 * turno `ativo` cujo `check_in_at` está NO PASSADO (≈ 1h atrás) — diferente do TurnosSeeder, que
 * agenda a janela no futuro (lá o cronômetro zeraria). Os dois usuários abrem
 * `/turno/{id}/cronometro-poc` em navegadores distintos para demonstrar a sincronia ≤ 2s.
 *
 * Credenciais da demo (homolog):
 *   profissional.poc@turni.local / senha: password
 *   contratante.poc@turni.local  / senha: password
 */
class CronometroPocSeeder extends Seeder
{
    public function run(): void
    {
        $contratante = User::updateOrCreate(
            ['email' => 'contratante.poc@turni.local'],
            [
                'name' => 'Contratante PoC Cronômetro',
                'password' => Hash::make('password'),
                'role' => 'contratante',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'welcome_seen_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        $profissional = User::updateOrCreate(
            ['email' => 'profissional.poc@turni.local'],
            [
                'name' => 'Profissional PoC Cronômetro',
                'password' => Hash::make('password'),
                'role' => 'profissional',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'welcome_seen_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        // Idempotência: reusa o turno ativo da PoC se já existe.
        $existente = Turno::where('contratante_id', $contratante->id)
            ->where('status', TurnoStatus::Ativo)
            ->first();
        if ($existente !== null) {
            $this->command?->info("CronometroPocSeeder: turno ativo já existe → {$existente->id}");

            return;
        }

        $funcaoId = Funcao::query()->orderBy('nome')->value('id');
        if ($funcaoId === null) {
            $this->command?->warn('CronometroPocSeeder: requer FuncaoSeeder antes. Pulado.');

            return;
        }

        $inicio = now()->subHour();          // check-in há ~1h → cronômetro já marcando
        $fim = now()->addHours(5);           // turno ainda em andamento

        $vaga = Vaga::create([
            'contratante_id' => $contratante->id,
            'funcao_id' => $funcaoId,
            'data_inicio' => $inicio,
            'data_fim' => $fim,
            'valor' => 200.00,
            'posicoes' => 1,
            'posicoes_preenchidas' => 1,
            'observacoes' => 'Vaga da PoC do cronômetro (STORY-057).',
            'lat' => -23.55,   // estabelecimento: SP centro
            'lng' => -46.63,
            'cidade' => 'São Paulo',
            'uf' => 'SP',
            'estado' => VagaEstado::Fechada,
            'versao_atual' => 1,
            'publicada_em' => now(),
            'fechada_em' => now(),
        ]);

        $candidatura = Candidatura::create([
            'vaga_id' => $vaga->id,
            'profissional_id' => $profissional->id,
            'estado' => CandidaturaEstado::Aprovada,
            'aprovada_em' => now(),
        ]);

        $turno = Turno::create([
            'candidatura_id' => $candidatura->id,
            'vaga_id' => $vaga->id,
            'vaga_versao_id' => null,
            'profissional_id' => $profissional->id,
            'contratante_id' => $contratante->id,
            'estabelecimento_id' => $contratante->id,
            'status' => TurnoStatus::Ativo,
            'valor' => 200.00,
            'taxa_turni' => 30.00,
            'total_contratante' => 230.00,
            'data_inicio' => $inicio,
            'data_fim' => $fim,
            'check_in_at' => $inicio, // âncora do cronômetro (passado)
            'check_out_at' => null,
        ]);

        $this->command?->info('CronometroPocSeeder: turno ativo da PoC criado.');
        $this->command?->info("  turno_id .......... {$turno->id}");
        $this->command?->info('  profissional ...... profissional.poc@turni.local / password');
        $this->command?->info('  contratante ....... contratante.poc@turni.local / password');
        $this->command?->info("  URL ............... /turno/{$turno->id}/cronometro-poc");
    }
}
