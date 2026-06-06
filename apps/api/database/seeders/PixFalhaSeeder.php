<?php

namespace Database\Seeders;

use App\Enums\TurnoStatus;
use App\Models\PixFalha;
use App\Models\Turno;
use Illuminate\Database\Seeder;

/**
 * STORY-065 — caso DETERMINÍSTICO na fila "Pix com falha" para o E2E do Backoffice
 * (dev/homolog; nunca prod). No fluxo real quem cria o caso é o worker (webhook
 * `transfer.failed` do fake — CA-5); este seed garante material de teste estável
 * sem depender do modo `falha` do fake.
 *
 * Idempotente com RECRIAÇÃO: o E2E resolve o caso (consome); o próximo seed reabre
 * com os mesmos dados (mesma disciplina do recriaConsumido do TurnosSeeder). Sem
 * fake()/factory (seed roda em homolog — disciplina de deploy).
 */
class PixFalhaSeeder extends Seeder
{
    public function run(): void
    {
        // Ancora num turno finalizado do TurnosSeeder (estado terminal — estável).
        $turno = Turno::query()
            ->where('status', TurnoStatus::Finalizado)
            ->orderBy('id')
            ->first();

        if ($turno === null) {
            $this->command?->warn('PixFalhaSeeder: nenhum turno finalizado (rode TurnosSeeder antes). Pulado.');

            return;
        }

        PixFalha::updateOrCreate(
            ['turno_id' => $turno->id],
            [
                'tipo' => 'pix',
                'profissional_nome' => 'Carlos Pix Falho (seed)',
                'funcao' => 'Garçom',
                'estabelecimento' => 'Bar do Zé (seed)',
                'valor' => 200.00,
                'chave_pix' => 'carlos.seed@pix.turni.local',
                'razao' => 'invalid_pix_key — chave não encontrada na instituição de destino (seed E2E)',
                'payload_gateway' => ['transfer_id' => 'tr_seed_e2e', 'reason' => 'invalid_pix_key'],
                'falhou_em' => now()->subHours(2),
                // Reabre o caso consumido pelo E2E anterior (resolução é humana no
                // fluxo real; aqui é material de teste).
                'resolvido_em' => null,
                'resolvido_por' => null,
                'nota_resolucao' => null,
            ],
        );

        // STORY-066 (CA-4) — caso de LIBERAÇÃO na fila generalizada "Falhas de
        // pagamento": ancora num turno cancelado (terminal estável); valor = total
        // reservado do contratante, sem chave Pix (tratamento é no gateway).
        $cancelado = Turno::query()
            ->whereIn('status', [TurnoStatus::CanceladoPro, TurnoStatus::CanceladoEmp])
            ->orderBy('id')
            ->first();

        if ($cancelado !== null) {
            PixFalha::updateOrCreate(
                ['turno_id' => $cancelado->id],
                [
                    'tipo' => 'liberacao',
                    'profissional_nome' => 'Pedro Liberação Falha (seed)',
                    'funcao' => 'Garçom',
                    'estabelecimento' => 'Bar do Zé (seed)',
                    'valor' => 230.00,
                    'chave_pix' => null,
                    'razao' => 'release_failed — pré-autorização não encontrada no gateway (seed E2E)',
                    'payload_gateway' => ['charge_id' => 'ch_seed_e2e', 'reason' => 'release_failed'],
                    'falhou_em' => now()->subHour(),
                    'resolvido_em' => null,
                    'resolvido_por' => null,
                    'nota_resolucao' => null,
                ],
            );
        }

        $this->command?->info('PixFalhaSeeder: casos abertos na fila "Falhas de pagamento" (pix + liberação).');
    }
}
