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
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-051 (CA-10) — vaga do `contratante.teste` (o contratante do login E2E) com 3 candidaturas
 * ranqueáveis, para o E2E do painel de candidatos:
 *
 *   contratante.teste loga → "Minhas vagas" mostra esta vaga → "Ver candidatos" → painel com os
 *   3 candidatos NA ORDEM (92 → 88 → 71) e breakdown expansível.
 *
 * Cada candidatura carrega o **snapshot persistido** (`score_no_momento` + `score_breakdown`)
 * como o POST real faria (STORY-050 + a coluna desta estória) — o painel lê sem recalcular
 * (CA-2/CA-4). Um dos candidatos carrega `alerta_habitualidade = true` (badge laranja — CA-5).
 *
 * Idempotente: marca a vaga por `observacoes` e não recria candidaturas se já existem. Roda
 * DEPOIS de AdminUserSeeder (contratante.teste) + FuncaoSeeder. DEV/HOMOLOG — inócuo em prod
 * (o contratante.teste não existe lá).
 */
class PainelCandidatosSeeder extends Seeder
{
    private const MARCADOR = 'e2e-painel-candidatos';

    public function run(): void
    {
        $contratante = User::where('email', 'contratante.teste@turni.local')->first();
        $funcao = Funcao::query()->orderBy('id')->first();
        if ($contratante === null || $funcao === null) {
            return;
        }

        $vaga = $this->vaga($contratante->id, $funcao->id);

        // Restaura a vaga para `aberta` a cada seed: o E2E de "Minhas vagas" cancela uma vaga
        // arbitrária (`Cancelar vaga`.first), então a vaga seed pode ter virado `cancelada` numa
        // execução anterior. Reabrir garante que o painel (que exige `aberta` para o botão "Ver
        // candidatos") encontre a vaga determinística em toda execução. Idempotente.
        if ($vaga->estado !== VagaEstado::Aberta) {
            $vaga->forceFill([
                'estado' => VagaEstado::Aberta,
                'cancelada_em' => null,
                'fechada_em' => null,
            ])->save();
        }

        // Candidaturas já semeadas? Não recria (idempotência por db:seed repetido).
        if (Candidatura::where('vaga_id', $vaga->id)->exists()) {
            return;
        }

        // [nome curto, e-mail, nível, score histórico, score do match, breakdown, alerta]
        $candidatos = [
            ['Júlia Santos', 'candidata.julia@turni.local', 'Elite', 4.90, 92,
                $this->breakdown(40, 'ok', 'Função primária bate', 20, 'ok', 'A 2 km do estabelecimento', 22, 'partial', 'Média 4,9★ em 127 turnos', 10, 'ok', 'Elite na trilha'), false],
            ['Bruno Costa', 'candidato.bruno@turni.local', 'Destaque', 4.70, 88,
                $this->breakdown(40, 'ok', 'Função primária bate', 18, 'partial', 'A 6 km do estabelecimento', 24, 'partial', 'Média 4,7★ em 64 turnos', 6, 'partial', 'Destaque na trilha'), true],
            ['Carlos Lima', 'candidato.carlos@turni.local', 'Confiável', 4.80, 71,
                $this->breakdown(25, 'partial', 'Função secundária bate', 20, 'ok', 'A 1 km do estabelecimento', 23, 'partial', 'Média 4,8★ em 31 turnos', 3, 'partial', 'Confiável na trilha'), false],
        ];

        $versaoId = $vaga->versoes()->value('id');
        foreach ($candidatos as $i => [$nome, $email, $nivel, $scoreHist, $score, $breakdown, $alerta]) {
            $prof = $this->profissional($email, $nome, $funcao->id, $nivel, $scoreHist);

            Candidatura::create([
                'vaga_id' => $vaga->id,
                'profissional_id' => $prof->id,
                'estado' => CandidaturaEstado::Pendente,
                'vaga_versao_id' => $versaoId,
                'score_no_momento' => $score,
                'score_breakdown' => $breakdown,
                'alerta_habitualidade' => $alerta,
                // Carimbo crescente: empate de score (não há aqui) desempataria por candidatou_em ASC.
                'created_at' => now()->subMinutes((3 - $i) * 5),
                'updated_at' => now(),
            ]);
        }

        $this->command?->info('PainelCandidatosSeeder: vaga do contratante.teste + 3 candidaturas ranqueadas.');
    }

    private function vaga(string $contratanteId, string $funcaoId): Vaga
    {
        $existente = Vaga::where('observacoes', self::MARCADOR)->first();
        if ($existente !== null) {
            return $existente;
        }

        $inicio = now()->addDays(12)->setTime(18, 0);
        $vaga = Vaga::create([
            'contratante_id' => $contratanteId,
            'funcao_id' => $funcaoId,
            'data_inicio' => $inicio,
            'data_fim' => (clone $inicio)->addHours(5),
            'valor' => 150.00,
            'posicoes' => 3,
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

    private function profissional(string $email, string $nome, string $funcaoId, string $nivel, float $score): User
    {
        $user = User::updateOrCreate(
            ['email' => $email],
            [
                'name' => $nome,
                'password' => Hash::make('password'),
                'role' => 'profissional',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'welcome_seen_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        ProfissionalProfile::updateOrCreate(
            ['user_id' => $user->id],
            [
                'tipo_pessoa' => 'MEI',
                'cidade' => 'São Paulo',
                'bairro' => 'Centro',
                'funcao_id' => $funcaoId,
                'lat' => -23.55,
                'lng' => -46.63,
                'raio_max_km' => 50,
                'nivel' => $nivel,
                'score' => $score,
                'turnos_realizados' => 60,
            ],
        );

        return $user;
    }

    /**
     * Monta o snapshot no shape de MatchScore::toArray() (STORY-045) — total = soma dos 4
     * componentes; é o que o painel lê sem recalcular (CA-4).
     *
     * @return array<string,mixed>
     */
    private function breakdown(
        int $fPts, string $fEst, string $fDesc,
        int $dPts, string $dEst, string $dDesc,
        int $hPts, string $hEst, string $hDesc,
        int $nPts, string $nEst, string $nDesc,
    ): array {
        $linha = fn (int $pts, int $max, string $est, string $desc): array => [
            'pontos' => $pts, 'pontos_max' => $max, 'estado' => $est, 'descricao' => $desc,
        ];

        return [
            'total' => $fPts + $dPts + $hPts + $nPts,
            'componentes' => ['funcao' => $fPts, 'distancia' => $dPts, 'historico' => $hPts, 'nivel' => $nPts],
            'breakdown' => [
                'funcao' => $linha($fPts, 40, $fEst, $fDesc),
                'distancia' => $linha($dPts, 20, $dEst, $dDesc),
                'historico' => $linha($hPts, 30, $hEst, $hDesc),
                'nivel' => $linha($nPts, 10, $nEst, $nDesc),
            ],
        ];
    }
}
