<?php

namespace Database\Seeders;

use App\Enums\VagaEstado;
use App\Models\Funcao;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-044 / ADR-013 (CA-7) — seed mínimo do EPIC-002: 1 contratante seed + 5 vagas
 * em estados variados (3 abertas, 1 fechada, 1 cancelada) com funções distintas.
 * Idempotente: reusa o contratante por e-mail e não recria as vagas se já existirem.
 * Depende de FuncaoSeeder (≥5 funções).
 */
class VagasSeeder extends Seeder
{
    public function run(): void
    {
        $contratante = User::updateOrCreate(
            ['email' => 'contratante.seed@turni.local'],
            [
                'name' => 'Estabelecimento Seed',
                'password' => Hash::make('password'),
                'role' => 'contratante',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'welcome_seen_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        // Idempotência: se o contratante seed já tem vagas, não recria.
        if (Vaga::where('contratante_id', $contratante->id)->exists()) {
            return;
        }

        $funcoes = Funcao::query()->orderBy('id')->take(5)->pluck('id')->all();
        if (count($funcoes) < 5) {
            $this->command?->warn('VagasSeeder: menos de 5 funções disponíveis — rode FuncaoSeeder antes.');

            return;
        }

        // [estado, posicoes, preenchidas] — 3 abertas, 1 fechada, 1 cancelada.
        $perfis = [
            [VagaEstado::Aberta, 1, 0],
            [VagaEstado::Aberta, 2, 1],
            [VagaEstado::Aberta, 3, 0],
            [VagaEstado::Fechada, 1, 1],
            [VagaEstado::Cancelada, 1, 0],
        ];

        foreach ($perfis as $i => [$estado, $posicoes, $preenchidas]) {
            $inicio = now()->addDays($i + 2)->setTime(18, 0);

            $vaga = Vaga::create([
                'contratante_id' => $contratante->id,
                'funcao_id' => $funcoes[$i],
                'data_inicio' => $inicio,
                'data_fim' => (clone $inicio)->addHours(6),
                'valor' => 120 + ($i * 30),
                'posicoes' => $posicoes,
                'posicoes_preenchidas' => $preenchidas,
                'observacoes' => 'Vaga seed #'.($i + 1),
                'lat' => -23.55 + ($i * 0.01),
                'lng' => -46.63 + ($i * 0.01),
                'cidade' => 'São Paulo',
                'uf' => 'SP',
                'estado' => $estado,
                'versao_atual' => 1,
                'publicada_em' => now(),
                'fechada_em' => $estado === VagaEstado::Fechada ? now() : null,
                'cancelada_em' => $estado === VagaEstado::Cancelada ? now() : null,
            ]);

            // Versão 1 (snapshot inicial na publicação — ADR-013 Decisão 1).
            VagaVersao::create([
                'vaga_id' => $vaga->id,
                'versao' => 1,
                'snapshot' => [
                    'funcao_id' => $vaga->funcao_id,
                    'data_inicio' => $vaga->data_inicio->toIso8601String(),
                    'data_fim' => $vaga->data_fim->toIso8601String(),
                    'valor' => (float) $vaga->valor,
                    'posicoes' => $vaga->posicoes,
                    'observacoes' => $vaga->observacoes,
                    'lat' => (float) $vaga->lat,
                    'lng' => (float) $vaga->lng,
                ],
                'editado_por' => $contratante->id,
            ]);
        }
    }
}
