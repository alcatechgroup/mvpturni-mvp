<?php

namespace Database\Seeders;

use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Models\Candidatura;
use App\Models\Funcao;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Carbon\CarbonInterface;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-058 (CA-9) — cenário determinístico do E2E de APROVAÇÃO no WebApp:
 *
 *   contratante.teste loga → "Minhas vagas" → vaga desta seed ("1 candidato aguardando")
 *   → painel → "Aceitar candidatura" → D1 → confirmar → turno criado.
 *
 * Determinismo entre execuções (turno/aceite são IMUTÁVEIS — não dá para "desfazer" no
 * reseed): cada vez que a candidatura anterior já foi consumida (aprovada → turno), o seeder
 * cria uma VAGA NOVA numa SEMANA AINDA NÃO USADA pelo par (profissional fixo × contratante.
 * teste) — a janela avança 1 semana por turno existente, então a habitualidade (PDR-002,
 * semana corrida seg→dom) nunca acumula e o fluxo é sempre o caminho feliz, sem override.
 *
 * A vaga fica SEMPRE com data_inicio depois da vaga do PainelCandidatosSeeder (+12 dias):
 * "Minhas vagas" ordena por data_inicio ASC e o E2E do painel tapeia o PRIMEIRO botão
 * "Ver candidatos" — esta vaga não pode roubar essa posição.
 *
 * DEV/HOMOLOG — inócuo em prod (contratante.teste não existe lá).
 */
class AprovacaoCandidaturaSeeder extends Seeder
{
    private const MARCADOR = 'e2e-aprovacao-candidatura';

    private const PROF_EMAIL = 'aprovacao.pro@turni.local';

    public function run(): void
    {
        $contratante = User::where('email', 'contratante.teste@turni.local')->first();
        $funcao = Funcao::query()->orderBy('id')->first();
        if ($contratante === null || $funcao === null) {
            return;
        }

        $prof = $this->profissional($funcao->id);

        // Já existe um cenário pronto (vaga aberta + candidatura pendente)? Não recria.
        $pronta = Vaga::where('observacoes', self::MARCADOR)
            ->where('estado', VagaEstado::Aberta)
            ->whereHas('candidaturas', fn ($q) => $q->where('estado', CandidaturaEstado::Pendente))
            ->exists();
        if ($pronta) {
            return;
        }

        // Semana virgem para o par (1 turno aprovado por execução anterior = 1 semana usada).
        $semanasUsadas = Turno::where('estabelecimento_id', $contratante->id)
            ->where('profissional_id', $prof->id)
            ->count();
        $inicio = now()->addWeeks(3 + $semanasUsadas)
            ->startOfWeek(CarbonInterface::MONDAY)
            ->addDays(3) // quinta-feira
            ->setTime(19, 0);

        $vaga = Vaga::create([
            'contratante_id' => $contratante->id,
            'funcao_id' => $funcao->id,
            'data_inicio' => $inicio,
            'data_fim' => (clone $inicio)->addHours(6),
            'valor' => 200.00,
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

        $versao = VagaVersao::create([
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
        ]);

        Candidatura::create([
            'vaga_id' => $vaga->id,
            'profissional_id' => $prof->id,
            'estado' => CandidaturaEstado::Pendente,
            'vaga_versao_id' => $versao->id,
            'score_no_momento' => 85,
            'score_breakdown' => null, // sem breakdown: o E2E foca o aceite, não o match
            'alerta_habitualidade' => false,
        ]);

        $this->command?->info('AprovacaoCandidaturaSeeder: vaga + candidatura pendente para o E2E de aprovação.');
    }

    /** Profissional MEI fixo do cenário (caminho feliz — sem override). */
    private function profissional(string $funcaoId): User
    {
        $prof = User::where('email', self::PROF_EMAIL)->first();
        if ($prof !== null) {
            return $prof;
        }

        $prof = User::create([
            'name' => 'Apro Vação',
            'email' => self::PROF_EMAIL,
            'password' => Hash::make('e2e-aprovacao'),
            'role' => 'profissional',
            'status' => 'ativo',
            'cadastro_completed_at' => now(),
            'welcome_seen_at' => now(),
        ]);

        $prof->profissionalProfile()->create([
            'tipo_pessoa' => 'MEI',
            'cidade' => 'São Paulo',
            'bairro' => 'Centro',
            'funcao_id' => $funcaoId,
            'funcoes_secundarias' => [],
            'lat' => -23.55,
            'lng' => -46.63,
            'raio_max_km' => 50,
            'nivel' => 'Confiável',
            'score' => 4.6,
            'turnos_realizados' => 20,
        ]);

        return $prof;
    }
}
