<?php

namespace Database\Seeders;

use App\Enums\CandidaturaEstado;
use App\Enums\TurnoStatus;
use App\Enums\VagaEstado;
use App\Models\AceiteEletronicoTurno;
use App\Models\Candidatura;
use App\Models\Funcao;
use App\Models\TemplateVersao;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-055 / ADR-015 (CA-7) — seed dos 11 estados do Turno (dev/homolog). A partir daqui,
 * as próximas estórias do EPIC-003 seedam cenários sem reimplementar a montagem.
 *
 * PRODUCTION-SAFE: cria tudo via Model::create (sem factories — `fake()` não existe em
 * produção/homolog, onde o job de migração roda com APP_ENV=production). Coerência: um
 * contratante (= estabelecimento, convenção MVP) e um profissional compartilhados; uma vaga
 * fechada + candidatura aprovada por turno (UNIQUE(vaga_id, profissional_id) exige vaga
 * distinta por turno). Cada turno recebe um AceiteEletronicoTurno imutável reusando a versão
 * ativa do template PF (TemplatesContratuaisSeeder); o `confirmado` demonstra o override de
 * habitualidade (PDR-002). Idempotente: não recria se já houver turnos do contratante seed.
 * Turnos são inseridos diretamente no estado-alvo (INSERT; o trigger só guarda UPDATE).
 *
 * Depende de FuncaoSeeder + TemplatesContratuaisSeeder.
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

        $funcaoId = Funcao::query()->orderBy('nome')->value('id');
        // Versão ativa do template contratual PF — reusa (não cria template novo, p/ não
        // poluir o catálogo do Backoffice).
        $templateVersaoId = TemplateVersao::query()
            ->whereHas('template', fn ($q) => $q->where('slug', 'pf_autonomo_eventual'))
            ->where('ativa', true)
            ->value('id');

        if ($funcaoId === null || $templateVersaoId === null) {
            $this->command?->warn('TurnosSeeder: requer FuncaoSeeder + TemplatesContratuaisSeeder antes. Pulado.');

            return;
        }

        foreach (TurnoStatus::cases() as $i => $status) {
            $inicio = now()->addDays($i + 2)->setTime(18, 0);
            $fim = (clone $inicio)->addHours(6);

            // Uma vaga fechada por turno (posição preenchida pela candidatura aprovada).
            $vaga = Vaga::create([
                'contratante_id' => $contratante->id,
                'funcao_id' => $funcaoId,
                'data_inicio' => $inicio,
                'data_fim' => $fim,
                'valor' => 200.00,
                'posicoes' => 1,
                'posicoes_preenchidas' => 1,
                'observacoes' => 'Vaga seed do turno #'.($i + 1).' ('.$status->value.')',
                'lat' => -23.55,
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
                'estabelecimento_id' => $contratante->id, // = contratante no MVP
                'status' => $status,
                'valor' => 200.00,
                'taxa_turni' => 30.00,         // 15% (PDR-004)
                'total_contratante' => 230.00, // valor + taxa
                'data_inicio' => $inicio,
                'data_fim' => $fim,
                'check_in_at' => $this->temCheckIn($status) ? (clone $inicio)->addMinutes(2) : null,
                'check_out_at' => $this->temCheckOut($status) ? $fim : null,
                'cancelamento' => $this->cancelamento($status, $inicio),
            ]);

            // Todo turno nasce com aceite imutável; o `confirmado` demonstra o override PJ.
            AceiteEletronicoTurno::create([
                'turno_id' => $turno->id,
                'template_versao_id' => $templateVersaoId,
                'conteudo_renderizado' => 'Contrato eventual de turno — '.$status->value.'. Valor R$ 200,00.',
                'dados_renderizados' => [
                    'turno.valor' => 'R$ 200,00',
                    'turno.taxa_turni' => 'R$ 30,00',
                    'turno.total_contratante' => 'R$ 230,00',
                    'habitualidade.override_aceito' => $status === TurnoStatus::Confirmado,
                ],
                'ip' => '127.0.0.1',
                'fingerprint' => hash('sha256', 'seed:'.$turno->id.':'.now()->toDateString()),
                'habitualidade_override' => $status === TurnoStatus::Confirmado,
            ]);
        }

        $this->command?->info('TurnosSeeder: 11 turnos (um por estado) + aceites criados.');
    }

    /** Estados em que o check-in já foi validado. */
    private function temCheckIn(TurnoStatus $status): bool
    {
        return in_array($status, [
            TurnoStatus::Ativo, TurnoStatus::AguardandoCheckout, TurnoStatus::EmDisputa,
            TurnoStatus::Finalizado, TurnoStatus::FinalizadoAjustado,
            TurnoStatus::DisputaResolvidaSemPagamento,
        ], true);
    }

    /** Estados em que o check-out já foi validado. */
    private function temCheckOut(TurnoStatus $status): bool
    {
        return in_array($status, [TurnoStatus::Finalizado, TurnoStatus::FinalizadoAjustado], true);
    }

    /** Payload de cancelamento (PDR-007) para os estados cancelados; null caso contrário. */
    private function cancelamento(TurnoStatus $status, \DateTimeInterface $inicio): ?array
    {
        if (! in_array($status, [TurnoStatus::CanceladoPro, TurnoStatus::CanceladoEmp], true)) {
            return null;
        }

        return [
            'lado' => $status === TurnoStatus::CanceladoPro ? 'pro' : 'emp',
            'motivo' => null,
            'antecedencia_horas' => 12,
            'em' => now()->toIso8601String(),
        ];
    }
}
