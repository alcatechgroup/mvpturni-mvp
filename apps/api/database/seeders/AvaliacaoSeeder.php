<?php

namespace Database\Seeders;

use App\Domain\Avaliacao\MotorReputacao;
use App\Enums\AvaliacaoDirecao;
use App\Enums\CandidaturaEstado;
use App\Enums\TurnoStatus;
use App\Enums\VagaEstado;
use App\Models\Avaliacao;
use App\Models\Candidatura;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-085 — massa de teste da avaliação recíproca (dev/homolog; nunca prod — o deploy de
 * produção é migrate-only). Cria um par dedicado (profissional.avaliacao / contratante.avaliacao)
 * com turnos finalizados entre eles:
 *
 *  - 3 turnos JÁ AVALIADOS nas duas direções (com comentário) → o profissional ganha
 *    score/nível/XP + depoimentos (estabelecimento nominal); o contratante ganha score +
 *    depoimentos (autor anônimo — LGPD/DDR-004);
 *  - 1 turno PENDENTE nas duas direções → dá para logar como qualquer lado e enviar uma
 *    avaliação nova, observando a reputação se mover (e a notificação "avalie seu turno").
 *
 * Roda o MotorReputacao ao final (reputação reflete os fatos). Idempotente: se o par já tem
 * turnos, só recomputa e sai.
 *
 * IMPORTANTE: tudo via `Model::create()` MANUAL — sem `::factory()`/`fake()`, que vivem em
 * require-dev e NÃO existem na imagem `--no-dev` do deploy (mesmo padrão do TurnosSeeder).
 */
class AvaliacaoSeeder extends Seeder
{
    public function run(): void
    {
        $senha = Hash::make(env('ADMIN_SEED_PASSWORD', 'turni-dev'));

        $pro = User::updateOrCreate(
            ['email' => 'profissional.avaliacao@turni.local'],
            [
                'name' => 'Pro Avaliação (seed)',
                'password' => $senha,
                'role' => 'profissional',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'welcome_seen_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        $emp = User::updateOrCreate(
            ['email' => 'contratante.avaliacao@turni.local'],
            [
                'name' => 'Contratante Avaliação (seed)',
                'password' => $senha,
                'role' => 'contratante',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'welcome_seen_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        $funcaoId = Funcao::query()->orderBy('nome')->value('id');

        if ($funcaoId === null) {
            $this->command?->warn('AvaliacaoSeeder: requer FuncaoSeeder antes. Pulado.');

            return;
        }

        ProfissionalProfile::firstOrCreate(
            ['user_id' => $pro->id],
            [
                'tipo_pessoa' => 'MEI',
                'cidade' => 'São Paulo',
                'bairro' => 'Pinheiros',
                'funcao_id' => $funcaoId,
                'funcoes_secundarias' => [],
                'lat' => -23.561,
                'lng' => -46.690,
                'raio_max_km' => 30,
                'nivel' => 'Iniciante',
                'score' => 0,
                'xp' => 0,
                'turnos_realizados' => 0,
            ],
        );

        ContratanteProfile::firstOrCreate(
            ['user_id' => $emp->id],
            [
                'nome_estabelecimento' => 'Cantina da Avaliação Ltda',
                'apelido_estabelecimento' => 'Cantina da Praça',
                'tipo_operacao' => 'restaurante',
                'cidade' => 'São Paulo',
                'score' => 0,
            ],
        );

        // Idempotência: se já há turnos do par, só recomputa e sai (deploy roda o seed a cada rc).
        if (Turno::where('contratante_id', $emp->id)->where('profissional_id', $pro->id)->exists()) {
            $this->recomputar($pro, $emp);

            return;
        }

        // 3 turnos avaliados nas duas direções (semanas passadas distintas).
        $avaliados = [
            ['pro' => 5, 'proC' => 'Pontual, proativo e muito simpático com os clientes.',
                'emp' => 5, 'empC' => 'Estabelecimento organizado e equipe acolhedora.', 'sem' => 6],
            ['pro' => 5, 'proC' => 'Atendimento impecável, dominou o salão sozinho.',
                'emp' => 4, 'empC' => 'Boa estrutura, só o horário de pico foi corrido.', 'sem' => 4],
            ['pro' => 4, 'proC' => 'Caprichoso e pontual; voltaria a contratar.',
                'emp' => 5, 'empC' => 'Gestão atenciosa e pagamento em dia.', 'sem' => 2],
        ];

        foreach ($avaliados as $c) {
            $turno = $this->turnoFinalizado($pro, $emp, $funcaoId, $c['sem']);

            // Contratante → profissional (depoimento nominal sobre o profissional).
            Avaliacao::create([
                'turno_id' => $turno->id,
                'autor_id' => $emp->id,
                'avaliado_id' => $pro->id,
                'direcao' => AvaliacaoDirecao::ContratanteParaProfissional,
                'estrelas' => $c['pro'],
                'comentario' => $c['proC'],
            ]);

            // Profissional → contratante (depoimento anônimo sobre o contratante — LGPD).
            Avaliacao::create([
                'turno_id' => $turno->id,
                'autor_id' => $pro->id,
                'avaliado_id' => $emp->id,
                'direcao' => AvaliacaoDirecao::ProfissionalParaContratante,
                'estrelas' => $c['emp'],
                'comentario' => $c['empC'],
            ]);
        }

        // 1 turno PENDENTE nas duas direções (a semana mais recente) — para avaliar ao vivo.
        $this->turnoFinalizado($pro, $emp, $funcaoId, 1);

        $this->recomputar($pro, $emp);

        $this->command?->info('AvaliacaoSeeder: par avaliacao + 3 turnos avaliados + 1 pendente + reputação computada.');
    }

    /** Turno finalizado entre o par, iniciado há `$semanas` semanas (vaga fechada + candidatura aprovada). */
    private function turnoFinalizado(User $pro, User $emp, string $funcaoId, int $semanas): Turno
    {
        $inicio = now()->subWeeks($semanas)->setTime(18, 0);
        $fim = (clone $inicio)->addHours(6);

        $vaga = Vaga::create([
            'contratante_id' => $emp->id,
            'funcao_id' => $funcaoId,
            'data_inicio' => $inicio,
            'data_fim' => $fim,
            'valor' => 200.00,
            'posicoes' => 1,
            'posicoes_preenchidas' => 1,
            'observacoes' => 'Vaga seed da avaliação recíproca ('.$semanas.' sem atrás)',
            'lat' => -23.561,
            'lng' => -46.690,
            'cidade' => 'São Paulo',
            'uf' => 'SP',
            'estado' => VagaEstado::Fechada,
            'versao_atual' => 1,
            'publicada_em' => $inicio,
            'fechada_em' => $fim,
        ]);

        $candidatura = Candidatura::create([
            'vaga_id' => $vaga->id,
            'profissional_id' => $pro->id,
            'estado' => CandidaturaEstado::Aprovada,
            'aprovada_em' => $inicio,
        ]);

        return Turno::create([
            'candidatura_id' => $candidatura->id,
            'vaga_id' => $vaga->id,
            'vaga_versao_id' => null,
            'profissional_id' => $pro->id,
            'contratante_id' => $emp->id,
            'estabelecimento_id' => $emp->id,
            'status' => TurnoStatus::Finalizado,
            'valor' => 200.00,
            'taxa_turni' => 30.00,
            'total_contratante' => 230.00,
            'data_inicio' => $inicio,
            'data_fim' => $fim,
            'check_in_at' => $inicio,
            'check_out_at' => $fim,
        ]);
    }

    private function recomputar(User $pro, User $emp): void
    {
        $motor = app(MotorReputacao::class);
        $motor->recalcular($pro->fresh());
        $motor->recalcular($emp->fresh());
    }
}
