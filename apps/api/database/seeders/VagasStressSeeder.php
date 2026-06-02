<?php

namespace Database\Seeders;

use App\Models\Funcao;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-044 / ADR-013 Decisão 3 (CA-8) — popula ~1k vagas abertas para o microbenchmark
 * do feed (EXPLAIN ANALYZE do índice idx_vagas_feed < 100ms). DEV/HOMOLOG apenas — nunca
 * em produção. Não entra no DatabaseSeeder: roda só por chamada explícita
 * (`php artisan db:seed --class=VagasStressSeeder`).
 */
class VagasStressSeeder extends Seeder
{
    private const TOTAL = 1000;

    public function run(): void
    {
        if (app()->environment('production')) {
            $this->command?->warn('VagasStressSeeder não roda em produção — ignorado.');

            return;
        }

        $contratante = User::updateOrCreate(
            ['email' => 'contratante.stress@turni.local'],
            [
                'name' => 'Estabelecimento Stress',
                'password' => Hash::make('password'),
                'role' => 'contratante',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'welcome_seen_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        $funcoes = Funcao::query()->pluck('id')->all();
        if ($funcoes === []) {
            $this->command?->warn('VagasStressSeeder: rode FuncaoSeeder antes.');

            return;
        }

        $now = now();
        $rows = [];
        for ($i = 0; $i < self::TOTAL; $i++) {
            $inicio = (clone $now)->addDays(($i % 60) + 1)->setTime(18, 0);
            $rows[] = [
                'contratante_id' => $contratante->id,
                'funcao_id' => $funcoes[$i % count($funcoes)],
                'data_inicio' => $inicio,
                'data_fim' => (clone $inicio)->addHours(6),
                'valor' => 100 + ($i % 300),
                'posicoes' => 1,
                'posicoes_preenchidas' => 0,
                'observacoes' => null,
                // Espalha em ~0.5º de lat/lng em torno da Grande SP (bounding-box do raio).
                'lat' => -23.70 + (($i % 50) * 0.005),
                'lng' => -46.80 + (($i % 50) * 0.007),
                'cidade' => 'São Paulo',
                'uf' => 'SP',
                'estado' => 'aberta',
                'versao_atual' => 1,
                'publicada_em' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        foreach (array_chunk($rows, 250) as $chunk) {
            DB::table('vagas')->insert($chunk);
        }

        $this->command?->info('VagasStressSeeder: '.self::TOTAL.' vagas abertas inseridas.');
    }
}
