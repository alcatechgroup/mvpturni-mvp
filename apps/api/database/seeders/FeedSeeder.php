<?php

namespace Database\Seeders;

use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * STORY-048 (CA-11) — prepara o profissional de seed (`profissional.teste`) para o E2E do
 * feed: dá a ele função primária + 2 secundárias alinhadas às 3 vagas ABERTAS do
 * VagasSeeder (funções 0,1,2 por id), geolocalização na Grande SP dentro do raio dessas
 * vagas, e atributos de match (nível/score/turnos) que produzem scores ranqueáveis:
 *
 *   - vaga da função PRIMÁRIA  → 40 (função) + 20 (raio) + 15 (4.5★) + 10 (Elite) = 85  → Alto match
 *   - vagas das SECUNDÁRIAS    → 25 (função) + 20 (raio) + 15 (4.5★) + 10 (Elite) = 70  → não-alto
 *
 * Assim "Todas" mostra ≥3 vagas ranqueadas e "Alto match" encolhe a lista (1 vaga) — exatamente
 * o que o E2E exercita. Roda DEPOIS de FuncaoSeeder + VagasSeeder (ordem em DatabaseSeeder).
 * Idempotente: updateOrCreate pelo user_id. DEV/HOMOLOG — inócuo se o profissional não existir.
 */
class FeedSeeder extends Seeder
{
    public function run(): void
    {
        $profissional = User::where('email', 'profissional.teste@turni.local')->first();
        if ($profissional === null) {
            return;
        }

        // Mesma ordenação de funções que o VagasSeeder usa para as 3 vagas abertas.
        $funcoes = Funcao::query()->orderBy('id')->take(3)->pluck('id')->all();
        if (count($funcoes) < 3) {
            $this->command?->warn('FeedSeeder: menos de 3 funções — rode FuncaoSeeder antes.');

            return;
        }

        ProfissionalProfile::updateOrCreate(
            ['user_id' => $profissional->id],
            [
                'tipo_pessoa' => 'MEI',
                'cidade' => 'São Paulo',
                'bairro' => 'Centro',
                'funcao_id' => $funcoes[0],
                'funcoes_secundarias' => [$funcoes[1], $funcoes[2]],
                // Coincide com a vaga aberta de menor índice do VagasSeeder (lat/lng base).
                'lat' => -23.55,
                'lng' => -46.63,
                'raio_max_km' => 50,
                'nivel' => 'Elite',
                'score' => 4.5,
                'turnos_realizados' => 120,
            ],
        );

        $this->command?->info('FeedSeeder: profissional.teste preparado para o feed (função + geo + match).');
    }
}
