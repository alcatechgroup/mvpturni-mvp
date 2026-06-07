<?php

namespace Database\Seeders;

use App\Enums\VagaEstado;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * STORY-053 (CA-12 — smoke de e-mail em homolog) — cria um contratante com e-mail ENTREGÁVEL
 * (`xandroalmeida+turni-homolog@gmail.com`, capturável pelo PO) dono de uma vaga candidatável pelo
 * `profissional.teste`. Permite validar o fluxo real `candidatura → e-mail (Resend)` em homolog, já
 * que os usuários de seed padrão têm e-mail `@turni.local` (indeligível pelo Resend) e homolog não
 * tem Mailpit.
 *
 * Vaga espelha o que torna a vaga do feed candidatável (STORY-048/FeedSeeder): função PRIMÁRIA do
 * `profissional.teste` (1ª por id) + geo exata `-23.55/-46.63` (distância 0) → score alto,
 * `pode_candidatar`. `valor = 137` é distintivo para achar a vaga no feed/API.
 *
 * Idempotente. **Nunca em produção** — é dado de teste com PII de e-mail real.
 */
class Ca12EmailSmokeSeeder extends Seeder
{
    private const EMAIL = 'xandroalmeida+turni-homolog@gmail.com';

    private const VALOR_MARCADOR = 137.00;

    public function run(): void
    {
        // SEM gate de ambiente (de propósito): este seeder roda no mesmo `db:seed` que cria
        // admin@turni.local, profissional.teste, etc. — todo o DatabaseSeeder é dado de teste e a
        // PIPELINE só roda `db:seed` em homolog (prod é migrate-only, release.yml). Gatear por
        // environment('production') pularia homolog (que roda APP_ENV=production), e gatear por
        // APP_URL não funciona: o job de migração/seed não seta APP_URL (config('app.url')=localhost).
        // Por isso seguimos o padrão dos seeders que DEVEM rodar em homolog: ungated.
        $funcaoPrimaria = Funcao::query()->orderBy('id')->value('id');
        if ($funcaoPrimaria === null) {
            $this->command?->warn('Ca12EmailSmokeSeeder: sem funções — rode FuncaoSeeder antes.');

            return;
        }

        $contratante = User::updateOrCreate(
            ['email' => self::EMAIL],
            [
                'name' => 'Contratante CA-12 (smoke)',
                'password' => Hash::make('turni-dev'),
                'role' => 'contratante',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'welcome_seen_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        ContratanteProfile::updateOrCreate(
            ['user_id' => $contratante->id],
            [
                'nome_estabelecimento' => 'Estabelecimento CA-12 (smoke)',
                'apelido_estabelecimento' => 'CA-12 Smoke',
                'tipo_operacao' => 'bar',
                'cidade' => 'São Paulo',
                'uf' => 'SP',
            ],
        );

        // Data sempre futura (re-seed mantém a vaga candidatável). Idempotente por (contratante, função).
        $inicio = now()->addDays(5)->setTime(18, 0);

        $vaga = Vaga::updateOrCreate(
            ['contratante_id' => $contratante->id, 'funcao_id' => $funcaoPrimaria],
            [
                'data_inicio' => $inicio,
                'data_fim' => (clone $inicio)->addHours(4),
                'valor' => self::VALOR_MARCADOR,
                'posicoes' => 1,
                'posicoes_preenchidas' => 0,
                'observacoes' => 'CA-12 smoke — valida e-mail de candidatura em homolog',
                'lat' => -23.55,
                'lng' => -46.63,
                'cidade' => 'São Paulo',
                'uf' => 'SP',
                'estado' => VagaEstado::Aberta,
                'versao_atual' => 1,
                'publicada_em' => now(),
                'fechada_em' => null,
                'cancelada_em' => null,
            ],
        );

        // Snapshot v1 — append-only (firstOrCreate: nunca UPDATE, que o trigger bloquearia).
        VagaVersao::firstOrCreate(
            ['vaga_id' => $vaga->id, 'versao' => 1],
            [
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
            ],
        );

        // 2 profissionais ENTREGÁVEIS (Gmail) para os cenários edita/cancela do E2E (CA-12): eles
        // precisam RECEBER e-mail (vaga_editada_material / vaga_cancelada), então não podem ser
        // @turni.local (Resend rejeita). Função primária + geo iguais à vaga → candidatáveis.
        foreach (['prof1', 'prof2'] as $alias) {
            $this->profissionalEntregavel($alias, $funcaoPrimaria);
        }

        $this->command?->info("Ca12EmailSmokeSeeder: contratante {$contratante->email} + vaga {$vaga->id} (valor ".self::VALOR_MARCADOR.') + 2 profissionais Gmail prontos.');
    }

    // STORY-067: `funcoes.id` virou UUIDv7 na W27.5 (ADR-018/STORY-070) — o seeder ficou fora
    // do DatabaseSeeder após o CA-12 fechar e o tipo não foi atualizado junto.
    private function profissionalEntregavel(string $alias, string $funcaoPrimaria): void
    {
        $user = User::updateOrCreate(
            ['email' => "xandroalmeida+{$alias}-homolog@gmail.com"],
            [
                'name' => 'Profissional CA-12 '.strtoupper($alias),
                'password' => Hash::make('turni-dev'),
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
                'funcao_id' => $funcaoPrimaria,
                'lat' => -23.55,
                'lng' => -46.63,
                'raio_max_km' => 50,
                'nivel' => 'Elite',
                'score' => 4.5,
                'turnos_realizados' => 120,
            ],
        );
    }
}
