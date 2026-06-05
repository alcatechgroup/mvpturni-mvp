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
use App\Models\VagaVersao;
use Carbon\Carbon;
use Carbon\CarbonInterface;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-058 (CA-9) — cenários determinísticos dos E2E de APROVAÇÃO no WebApp (browser real):
 *
 *  1. CAMINHO FELIZ (Camareira / Arrumação · MEI · semana virgem): aceitar → D1 → turno.
 *  2. BLOQUEIO PF 3ª (Copeiro(a) · PF · semana com 2 turnos do par): aceitar → D1 → D2
 *     "Aceite bloqueado" (PDR-002, sem override). NADA é consumido — cenário estável.
 *  3. OVERRIDE PJ 3ª (Hostess / Recepção de Salão · MEI · semana com 2 turnos do par):
 *     aceitar → D1 (com pré-aviso) → D3 → "Assumo o risco e aceito" → turno com cláusula.
 *
 * Determinismo entre execuções (turno/aceite são IMUTÁVEIS — não há "desfazer" no reseed):
 * cenários que CONSOMEM (1 e 3) rotacionam para uma semana ainda não usada pelo par a cada
 * ciclo consumido; o bloqueio PF (2) não consome e vive numa semana fixa. Janelas-base bem
 * separadas (fev/jun/out de 2027) para nunca colidirem — e SEMPRE depois de 31/12/2026, a
 * data das vagas publicadas pelos E2E de publicar/editar ("Minhas vagas" ordena por
 * data_inicio ASC e aqueles testes tapeiam `.first`).
 *
 * Cada cenário usa uma FUNÇÃO exclusiva (nenhum outro seed/E2E a usa) — é por ela que o
 * teste acha o card da vaga. PRODUCTION-SAFE: só Model::create/updateOrCreate, sem fake().
 * Sobras abertas de ciclos anteriores são canceladas. DEV/HOMOLOG — inócuo em prod
 * (contratante.teste não existe lá). Depende de AdminUserSeeder + FuncaoSeeder; roda após
 * TurnosSeeder (convenção: cenários de turno montados via Model::create, ADR-015).
 */
class AprovacaoCandidaturaSeeder extends Seeder
{
    private const MARCADOR = 'e2e-aprovacao-candidatura';

    public function run(): void
    {
        $contratante = User::where('email', 'contratante.teste@turni.local')->first();
        if ($contratante === null) {
            return;
        }

        // Migração do marcador legado (rc.69 usava o marcador sem sufixo de cenário): renomeia
        // para o do caminho feliz, senão a vaga antiga ficaria órfã e duplicaria o card.
        Vaga::where('observacoes', self::MARCADOR)
            ->update(['observacoes' => self::MARCADOR.':camareira']);

        // 1. Caminho feliz — consome 1 turno/ciclo; rotaciona 1 semana por turno do par.
        $this->cenario(
            contratante: $contratante,
            email: 'aprovacao.pro@turni.local',
            nome: 'Apro Vação',
            tipoPessoa: 'MEI',
            funcaoSlug: 'camareira',
            baseSemana: '2027-02-01',
            turnosPreExistentes: 0,
            turnosPorCiclo: 1,
            alertaHabitualidade: false,
        );

        // 2. Bloqueio PF 3ª — nunca consome (semana fixa, 2 turnos eternos do par).
        $this->cenario(
            contratante: $contratante,
            email: 'aprovacao.pf@turni.local',
            nome: 'Pedro Fonseca',
            tipoPessoa: 'PF',
            funcaoSlug: 'copeiro',
            baseSemana: '2027-10-04',
            turnosPreExistentes: 2,
            turnosPorCiclo: 0,
            alertaHabitualidade: false,
        );

        // 3. Override PJ 3ª — consome 1 turno/ciclo; cada ciclo = 2 seed + 1 aprovado = 3.
        $this->cenario(
            contratante: $contratante,
            email: 'aprovacao.pj@turni.local',
            nome: 'Paula Junqueira',
            tipoPessoa: 'MEI',
            funcaoSlug: 'hostess',
            baseSemana: '2027-06-07',
            turnosPreExistentes: 2,
            turnosPorCiclo: 3,
            alertaHabitualidade: true,
        );
    }

    /**
     * Garante o cenário: vaga aberta (função exclusiva, semana-alvo) + candidatura pendente
     * + `turnosPreExistentes` turnos do par NA MESMA semana (a 3ª alocação — PDR-002).
     */
    private function cenario(
        User $contratante,
        string $email,
        string $nome,
        string $tipoPessoa,
        string $funcaoSlug,
        string $baseSemana,
        int $turnosPreExistentes,
        int $turnosPorCiclo,
        bool $alertaHabitualidade,
    ): void {
        $funcao = Funcao::where('slug', $funcaoSlug)->first();
        if ($funcao === null) {
            return;
        }

        $prof = $this->profissional($email, $nome, $tipoPessoa, $funcao->id);
        $marcador = self::MARCADOR.':'.$funcaoSlug;

        // Cenário pronto (vaga aberta + candidatura pendente)? Não recria.
        $pronta = Vaga::where('observacoes', $marcador)
            ->where('estado', VagaEstado::Aberta)
            ->whereHas('candidaturas', fn ($q) => $q->where('estado', CandidaturaEstado::Pendente))
            ->exists();
        if ($pronta) {
            return;
        }

        // Sobras abertas (cenário consumido/alterado por outro E2E): cancela — vaga
        // cancelada some do caminho dos outros testes (sem Editar/Cancelar/Ver candidatos).
        Vaga::where('observacoes', $marcador)
            ->where('estado', VagaEstado::Aberta)
            ->get()
            ->each(fn (Vaga $v) => $v->transitionTo(VagaEstado::Cancelada));

        // Semana-alvo: fixa (cenário que não consome) ou rotacionada por ciclo consumido.
        $ciclos = $turnosPorCiclo > 0
            ? intdiv(Turno::where('estabelecimento_id', $contratante->id)->where('profissional_id', $prof->id)->count(), $turnosPorCiclo)
            : 0;
        $inicio = now()->parse($baseSemana)->addWeeks($ciclos)
            ->startOfWeek(CarbonInterface::MONDAY)
            ->addDays(3) // quinta-feira
            ->setTime(19, 0);

        // Turnos pré-existentes do par na MESMA semana (seg/ter) — a vaga-alvo vira a 3ª.
        for ($i = 0; $i < $turnosPreExistentes; $i++) {
            $this->turnoDoPar($contratante, $prof, $funcao->id, $inicio->copy()->subDays(2 - $i)->setTime(10, 0), $marcador);
        }

        $vaga = $this->vagaAberta($contratante, $funcao->id, $inicio, $marcador);

        Candidatura::create([
            'vaga_id' => $vaga->id,
            'profissional_id' => $prof->id,
            'estado' => CandidaturaEstado::Pendente,
            'vaga_versao_id' => $vaga->versoes()->value('id'),
            'score_no_momento' => 85,
            'score_breakdown' => null, // sem breakdown: o E2E foca o aceite, não o match
            'alerta_habitualidade' => $alertaHabitualidade,
        ]);

        $this->command?->info("AprovacaoCandidaturaSeeder: cenário {$funcaoSlug} pronto ({$nome}, semana de {$inicio->toDateString()}).");
    }

    /** Profissional do cenário (tipo de pessoa controla PF×PJ na regra PDR-002). */
    private function profissional(string $email, string $nome, string $tipoPessoa, string $funcaoId): User
    {
        $prof = User::updateOrCreate(
            ['email' => $email],
            [
                'name' => $nome,
                'password' => Hash::make('e2e-aprovacao'),
                'role' => 'profissional',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'cadastro_completed_at' => now(),
                'welcome_seen_at' => now(),
            ],
        );

        if ($prof->profissionalProfile === null) {
            $prof->profissionalProfile()->create([
                'tipo_pessoa' => $tipoPessoa,
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
        }

        return $prof;
    }

    /** Vaga aberta (1 posição) na semana-alvo, marcada para idempotência/limpeza. */
    private function vagaAberta(User $contratante, string $funcaoId, Carbon $inicio, string $marcador): Vaga
    {
        $vaga = Vaga::create([
            'contratante_id' => $contratante->id,
            'funcao_id' => $funcaoId,
            'data_inicio' => $inicio,
            'data_fim' => (clone $inicio)->addHours(6),
            'valor' => 200.00,
            'posicoes' => 1,
            'posicoes_preenchidas' => 0,
            'observacoes' => $marcador,
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
        ]);

        return $vaga;
    }

    /**
     * Turno `confirmado` pré-existente do par profissional × contratante na semana-alvo —
     * é o que faz a vaga-alvo ser a 3ª alocação (PDR-002). Vaga fechada + candidatura
     * aprovada próprias (UNIQUE candidatura_id — padrão do TurnosSeeder, production-safe).
     */
    private function turnoDoPar(User $contratante, User $prof, string $funcaoId, Carbon $inicio, string $marcador): void
    {
        $vaga = Vaga::create([
            'contratante_id' => $contratante->id,
            'funcao_id' => $funcaoId,
            'data_inicio' => $inicio,
            'data_fim' => (clone $inicio)->addHours(6),
            'valor' => 200.00,
            'posicoes' => 1,
            'posicoes_preenchidas' => 1,
            'observacoes' => $marcador.':turno-preexistente',
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
            'profissional_id' => $prof->id,
            'estado' => CandidaturaEstado::Aprovada,
            'aprovada_em' => now(),
        ]);

        Turno::create([
            'candidatura_id' => $candidatura->id,
            'vaga_id' => $vaga->id,
            'vaga_versao_id' => null,
            'profissional_id' => $prof->id,
            'contratante_id' => $contratante->id,
            'estabelecimento_id' => $contratante->id, // = contratante no MVP
            'status' => TurnoStatus::Confirmado,
            'valor' => 200.00,
            'taxa_turni' => 30.00,         // 15% (PDR-004)
            'total_contratante' => 230.00, // valor + taxa
            'data_inicio' => $inicio,
            'data_fim' => (clone $inicio)->addHours(6),
        ]);
    }
}
