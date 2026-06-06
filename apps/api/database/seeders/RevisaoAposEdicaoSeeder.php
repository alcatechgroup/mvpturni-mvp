<?php

namespace Database\Seeders;

use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Models\Candidatura;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use App\Services\EditarVagaService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-073 (CA-3/CA-5) — cenário de verificação AO VIVO do Scheduler do Laravel em
 * homolog: reproduz o caminho do bug F-NB-1 do EPIC-002 com timestamps reais.
 *
 * Monta, pelo caminho REAL (EditarVagaService, como o PATCH do contratante):
 *   vaga do contratante.teste com candidatura `pendente` → edição material → candidatura
 *   em `pendente_revisao_apos_edicao` com `revisao_prazo_em` = INÍCIO DO TURNO (~5 min à
 *   frente), porque PDR-009 manda "24h OU início do turno, o que vier antes". Sem mexer
 *   em relógio: o prazo curto é a própria regra. O cron `candidaturas:auto-retirar-apos-
 *   edicao` (agora disparado 1×/min pelo Cloud Run Job `turni-scheduler-job-homolog`)
 *   retira a candidatura no primeiro tick após o prazo e audita
 *   `candidatura.retirada_por_edicao_auto`.
 *
 * MANUAL, não registrado no DatabaseSeeder: re-seedar a cada release re-dispararia a
 * retirada + e-mail a cada deploy. Uso (homolog, via job de migração com override, ou dev):
 *   php artisan db:seed --class=RevisaoAposEdicaoSeeder
 *
 * Idempotente e dono do cenário (padrão PainelCandidatosSeeder): cada execução restaura o
 * estado base (vaga aberta, candidatura pendente) e refaz a edição material — versões da
 * vaga acumulam (v2, v3, ...), como edições reais acumulariam.
 */
class RevisaoAposEdicaoSeeder extends Seeder
{
    public const MARCADOR = 'story073-revisao-pos-edicao';

    public const EMAIL_CANDIDATO = 'candidato.story073@turni.local';

    /** Minutos até o início do turno = janela real até a auto-retirada. */
    private const MINUTOS_ATE_INICIO = 5;

    public function run(): void
    {
        $contratante = User::where('email', 'contratante.teste@turni.local')->first();
        $funcao = Funcao::query()->orderBy('id')->first();
        if ($contratante === null || $funcao === null) {
            return; // pré-requisitos (AdminUserSeeder + FuncaoSeeder) ausentes — no-op.
        }

        $vaga = $this->vagaNoEstadoBase($contratante->id, $funcao->id);
        $this->candidaturaPendente($vaga, $funcao->id);

        // Caminho real do CA-3 (a): edição MATERIAL (data_inicio + valor) pelo serviço do
        // contratante. Carimba revisao_prazo_em = data_inicio (≈ +5 min) e audita.
        $inicio = now()->addMinutes(self::MINUTOS_ATE_INICIO);
        app(EditarVagaService::class)->editar($contratante, $vaga, [
            'funcao_id' => $vaga->funcao_id,
            'data_inicio' => $inicio->toDateTimeString(),
            'data_fim' => $inicio->copy()->addHours(4)->toDateTimeString(),
            'valor' => 175.00,
            'posicoes' => $vaga->posicoes,
            'observacoes' => self::MARCADOR, // preserva o marcador (observacoes é editável)
        ]);

        $this->command?->info(sprintf(
            'RevisaoAposEdicaoSeeder: candidatura em pendente_revisao_apos_edicao; prazo (início do turno) %s — auto-retirada esperada no 1º tick do scheduler após esse horário.',
            $inicio->format('Y-m-d H:i:s e'),
        ));
    }

    /** Vaga marcador restaurada ao estado base: aberta, início ~2h à frente, valor 150. */
    private function vagaNoEstadoBase(string $contratanteId, string $funcaoId): Vaga
    {
        $base = now()->addHours(2);

        $vaga = Vaga::where('observacoes', self::MARCADOR)->first();
        if ($vaga !== null) {
            $vaga->forceFill([
                'estado' => VagaEstado::Aberta,
                'cancelada_em' => null,
                'fechada_em' => null,
                'data_inicio' => $base,
                'data_fim' => (clone $base)->addHours(4),
                'valor' => 150.00,
            ])->save();

            return $vaga;
        }

        $vaga = Vaga::create([
            'contratante_id' => $contratanteId,
            'funcao_id' => $funcaoId,
            'data_inicio' => $base,
            'data_fim' => (clone $base)->addHours(4),
            'valor' => 150.00,
            'posicoes' => 1,
            'posicoes_preenchidas' => 0,
            'observacoes' => self::MARCADOR,
            'lat' => -23.55,
            'lng' => -46.63,
            'cidade' => 'São Paulo',
            'uf' => 'SP',
            'estado' => VagaEstado::Aberta,
            'versao_atual' => 1,
            'publicada_em' => now(),
        ]);

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
            'editado_por' => $contratanteId,
        ]);

        return $vaga;
    }

    /** Candidatura do candidato seed restaurada a `pendente` (o serviço fará a transição). */
    private function candidaturaPendente(Vaga $vaga, string $funcaoId): void
    {
        $candidato = User::updateOrCreate(
            ['email' => self::EMAIL_CANDIDATO],
            [
                'name' => 'Cândida Revisão (seed STORY-073)',
                'password' => Hash::make('password'),
                'role' => 'profissional',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'welcome_seen_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        ProfissionalProfile::updateOrCreate(
            ['user_id' => $candidato->id],
            [
                'tipo_pessoa' => 'MEI',
                'cidade' => 'São Paulo',
                'bairro' => 'Centro',
                'funcao_id' => $funcaoId,
                'lat' => -23.55,
                'lng' => -46.63,
                'raio_max_km' => 50,
                'nivel' => 'Confiável',
                'score' => 4.5,
                'turnos_realizados' => 10,
            ],
        );

        $existente = Candidatura::where('vaga_id', $vaga->id)
            ->where('profissional_id', $candidato->id)
            ->first();

        if ($existente !== null) {
            $existente->forceFill([
                'estado' => CandidaturaEstado::Pendente,
                'revisao_prazo_em' => null,
                'aprovada_em' => null,
                'retirada_em' => null,
            ])->save();

            return;
        }

        Candidatura::create([
            'vaga_id' => $vaga->id,
            'profissional_id' => $candidato->id,
            'estado' => CandidaturaEstado::Pendente,
            'vaga_versao_id' => $vaga->versoes()->value('id'),
            'score_no_momento' => 70,
        ]);
    }
}
