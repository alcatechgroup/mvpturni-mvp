<?php

namespace Database\Seeders;

use App\Enums\CandidaturaEstado;
use App\Enums\TurnoStatus;
use App\Enums\VagaEstado;
use App\Models\AceiteEletronicoTurno;
use App\Models\AuditLog;
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

        // Idempotência: se o contratante seed já tem turnos, não recria — mas backfilla a
        // trilha de auditoria dos turnos antigos (STORY-060: dev/homolog seedados antes da
        // timeline existir ficariam com histórico vazio no detalhe).
        if (Turno::where('contratante_id', $contratante->id)->exists()) {
            $this->backfillTimeline($contratante);
            $this->seedTurnoPinJanela(); // STORY-061 — independente dos 11 turnos acima
            $this->seedTurnoCronometro(); // STORY-063 — idem

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
            $aceite = AceiteEletronicoTurno::create([
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

            $this->seedTimeline($turno, $aceite, $status);
        }

        $this->command?->info('TurnosSeeder: 11 turnos (um por estado) + aceites + timeline criados.');

        $this->seedTurnoPinJanela();
        $this->seedTurnoCronometro();
    }

    /**
     * STORY-063 — turno `ativo` com usuários exclusivos (`*.cronometro.seed`) para o E2E
     * do cronômetro bilateral. O E2E é LEITURA PURA (o cronômetro não muta estado), então
     * o turno é estável entre execuções; o REFRESH só renova `check_in_at` (decorrido
     * ~35min) e as datas para o cenário não envelhecer em homolog. Production-safe.
     */
    private function seedTurnoCronometro(): void
    {
        $contratante = User::updateOrCreate(
            ['email' => 'contratante.cronometro.seed@turni.local'],
            [
                'name' => 'Estabelecimento Cronômetro Seed',
                'password' => Hash::make('password'),
                'role' => 'contratante',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        $profissional = User::updateOrCreate(
            ['email' => 'profissional.cronometro.seed@turni.local'],
            [
                'name' => 'Profissional Cronômetro Seed',
                'password' => Hash::make('password'),
                'role' => 'profissional',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        // Turno começou há ~35min e termina em ~5h — cronômetro vivo, formato HH:MM:SS.
        $inicio = now()->subMinutes(37)->startOfMinute();
        $checkIn = now()->subMinutes(35)->startOfMinute();
        $fim = (clone $inicio)->addHours(6);

        $existente = Turno::query()
            ->where('contratante_id', $contratante->id)
            ->orderByDesc('id')
            ->first();
        if ($existente !== null) {
            if ($existente->status === TurnoStatus::Ativo) {
                // Refresh — o trigger só valida MUDANÇA de status; aqui status fica.
                $existente->forceFill([
                    'data_inicio' => $inicio,
                    'data_fim' => $fim,
                    'check_in_at' => $checkIn,
                ])->save();
                $existente->vaga?->update(['data_inicio' => $inicio, 'data_fim' => $fim]);
                $this->command?->info('TurnosSeeder: turno cronômetro seed renovado (ativo, ~35min decorridos).');
            }

            return;
        }

        $funcaoId = Funcao::query()->orderBy('nome')->value('id');
        $templateVersaoId = TemplateVersao::query()
            ->whereHas('template', fn ($q) => $q->where('slug', 'pf_autonomo_eventual'))
            ->where('ativa', true)
            ->value('id');

        if ($funcaoId === null || $templateVersaoId === null) {
            $this->command?->warn('TurnosSeeder: turno cronômetro seed requer FuncaoSeeder + TemplatesContratuaisSeeder. Pulado.');

            return;
        }

        $vaga = Vaga::create([
            'contratante_id' => $contratante->id,
            'funcao_id' => $funcaoId,
            'data_inicio' => $inicio,
            'data_fim' => $fim,
            'valor' => 200.00,
            'posicoes' => 1,
            'posicoes_preenchidas' => 1,
            'observacoes' => 'Vaga seed do cronômetro bilateral (STORY-063)',
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
            'estabelecimento_id' => $contratante->id,
            'status' => TurnoStatus::Ativo,
            'valor' => 200.00,
            'taxa_turni' => 30.00,
            'total_contratante' => 230.00,
            'data_inicio' => $inicio,
            'data_fim' => $fim,
            'check_in_at' => $checkIn,
        ]);

        $aceite = AceiteEletronicoTurno::create([
            'turno_id' => $turno->id,
            'template_versao_id' => $templateVersaoId,
            'conteudo_renderizado' => 'Contrato eventual de turno — cronômetro bilateral. Valor R$ 200,00.',
            'dados_renderizados' => [
                'turno.valor' => 'R$ 200,00',
                'turno.taxa_turni' => 'R$ 30,00',
                'turno.total_contratante' => 'R$ 230,00',
            ],
            'ip' => '127.0.0.1',
            'fingerprint' => hash('sha256', 'seed:'.$turno->id.':'.now()->toDateString()),
            'habitualidade_override' => false,
        ]);

        $this->seedTimeline($turno, $aceite, TurnoStatus::Ativo);

        $this->command?->info('TurnosSeeder: turno cronômetro seed (ativo, ~35min decorridos) criado.');
    }

    /**
     * STORY-061/062 — turnos `confirmado` DENTRO da janela de check-in com usuários
     * exclusivos por estória (os E2E mutam estado e não podem contaminar a suíte da
     * 059/060, que usa os `*.turnos.seed`):
     *
     * - `*.pin.seed` (061): gerar/cancelar PIN — sempre volta a confirmado/aguardando,
     *   então basta o REFRESH da janela.
     * - `*.validar.seed` (062): a validação CONSOME o turno (ativo não volta — máquina
     *   de estados/trigger), então quando o turno foi consumido o seed cria um NOVO
     *   (vaga+candidatura+aceite novos; o antigo fica como histórico real — o aceite é
     *   imutável e o turno não pode ser deletado).
     *
     * Idempotente com REFRESH: a cada seed, `data_inicio` volta para now()+15min
     * enquanto o turno estiver em confirmado/aguardando_checkin — sem isso a janela
     * "envelhece" e o botão de gerar morre em homolog. Production-safe (sem fake()).
     */
    private function seedTurnoPinJanela(): void
    {
        $this->seedTurnoNaJanela(
            emailPrefixo: 'pin.seed',
            nomeBase: 'PIN Seed',
            observacao: 'Vaga seed do turno PIN de check-in (STORY-061)',
            rotulo: 'turno PIN seed',
            recriaConsumido: false,
        );

        $this->seedTurnoNaJanela(
            emailPrefixo: 'validar.seed',
            nomeBase: 'Validar Seed',
            observacao: 'Vaga seed da validação do check-in (STORY-062)',
            rotulo: 'turno validar seed',
            recriaConsumido: true,
        );

        // STORY-064: o E2E do ciclo completo (confirmado → … → finalizado, CA-8) também
        // CONSOME o turno — e um run interrompido pode deixá-lo em ativo/aguardando_checkout
        // (fora do refresh da janela) → recriaConsumido cobre os dois casos.
        $this->seedTurnoNaJanela(
            emailPrefixo: 'checkout.seed',
            nomeBase: 'Checkout Seed',
            observacao: 'Vaga seed do ciclo completo de check-out (STORY-064)',
            rotulo: 'turno checkout seed',
            recriaConsumido: true,
        );
    }

    private function seedTurnoNaJanela(
        string $emailPrefixo,
        string $nomeBase,
        string $observacao,
        string $rotulo,
        bool $recriaConsumido,
    ): void {
        $contratante = User::updateOrCreate(
            ['email' => "contratante.{$emailPrefixo}@turni.local"],
            [
                'name' => "Estabelecimento {$nomeBase}",
                'password' => Hash::make('password'),
                'role' => 'contratante',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        $profissional = User::updateOrCreate(
            ['email' => "profissional.{$emailPrefixo}@turni.local"],
            [
                'name' => "Profissional {$nomeBase}",
                'password' => Hash::make('password'),
                'role' => 'profissional',
                'status' => 'ativo',
                'email_verified_at' => now(),
                'cadastro_completed_at' => now(),
            ],
        );

        $inicio = now()->addMinutes(15)->startOfMinute();
        $fim = (clone $inicio)->addHours(6);

        // Mais recente por `id`: UUIDv7 é ordenável no tempo com precisão sub-segundo
        // (created_at empata quando dois seeds rodam no mesmo segundo — ADR-018).
        $existente = Turno::query()
            ->where('contratante_id', $contratante->id)
            ->orderByDesc('id')
            ->first();
        if ($existente !== null) {
            // Refresh da janela — o trigger só valida MUDANÇA de status; aqui status fica.
            if (in_array($existente->status, [TurnoStatus::Confirmado, TurnoStatus::AguardandoCheckin], true)) {
                $existente->forceFill(['data_inicio' => $inicio, 'data_fim' => $fim])->save();
                $existente->vaga?->update(['data_inicio' => $inicio, 'data_fim' => $fim]);
                $this->command?->info("TurnosSeeder: janela do {$rotulo} renovada.");

                return;
            }

            if (! $recriaConsumido) {
                return;
            }
            // Consumido (ativo/terminal) → cai na criação de um turno novo abaixo.
        }

        $funcaoId = Funcao::query()->orderBy('nome')->value('id');
        $templateVersaoId = TemplateVersao::query()
            ->whereHas('template', fn ($q) => $q->where('slug', 'pf_autonomo_eventual'))
            ->where('ativa', true)
            ->value('id');

        if ($funcaoId === null || $templateVersaoId === null) {
            $this->command?->warn("TurnosSeeder: {$rotulo} requer FuncaoSeeder + TemplatesContratuaisSeeder. Pulado.");

            return;
        }

        $vaga = Vaga::create([
            'contratante_id' => $contratante->id,
            'funcao_id' => $funcaoId,
            'data_inicio' => $inicio,
            'data_fim' => $fim,
            'valor' => 200.00,
            'posicoes' => 1,
            'posicoes_preenchidas' => 1,
            'observacoes' => $observacao,
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
            'estabelecimento_id' => $contratante->id,
            'status' => TurnoStatus::Confirmado,
            'valor' => 200.00,
            'taxa_turni' => 30.00,
            'total_contratante' => 230.00,
            'data_inicio' => $inicio,
            'data_fim' => $fim,
        ]);

        $aceite = AceiteEletronicoTurno::create([
            'turno_id' => $turno->id,
            'template_versao_id' => $templateVersaoId,
            'conteudo_renderizado' => 'Contrato eventual de turno — PIN de check-in. Valor R$ 200,00.',
            'dados_renderizados' => [
                'turno.valor' => 'R$ 200,00',
                'turno.taxa_turni' => 'R$ 30,00',
                'turno.total_contratante' => 'R$ 230,00',
            ],
            'ip' => '127.0.0.1',
            'fingerprint' => hash('sha256', 'seed:'.$turno->id.':'.now()->toDateString()),
            'habitualidade_override' => false,
        ]);

        $this->seedTimeline($turno, $aceite, TurnoStatus::Confirmado);

        $this->command?->info("TurnosSeeder: {$rotulo} (confirmado, na janela) criado.");
    }

    /** STORY-060 — anexa a trilha aos turnos do seed criados antes da timeline existir. */
    private function backfillTimeline(User $contratante): void
    {
        $turnos = Turno::query()
            ->where('contratante_id', $contratante->id)
            ->whereNotExists(fn ($q) => $q->from('audit_logs')
                ->whereColumn('audit_logs.target_id', 'turnos.id')
                ->where('audit_logs.target_type', 'Turno'))
            ->with('aceite')
            ->get();

        foreach ($turnos as $turno) {
            if ($turno->aceite !== null) {
                $this->seedTimeline($turno, $turno->aceite, $turno->status);
            }
        }

        if ($turnos->isNotEmpty()) {
            $this->command?->info("TurnosSeeder: trilha backfillada em {$turnos->count()} turnos.");
        }
    }

    /**
     * STORY-060 — trilha de auditoria coerente com o estado do turno, para a timeline do
     * detalhe ter história em dev/homolog (no fluxo real a 058+ grava os eventos; o seed
     * insere os turnos direto no estado-alvo e por isso replica a trilha aqui). Mesmos
     * `action`/`target` do fluxo real (AprovarCandidaturaService/PreAutorizarTurnoJob).
     */
    private function seedTimeline(Turno $turno, AceiteEletronicoTurno $aceite, TurnoStatus $status): void
    {
        // Eventos extra por estado, na ordem do ciclo (depois da base criado/aceite/preauth).
        $extras = match ($status) {
            TurnoStatus::Confirmado => [],
            TurnoStatus::AguardandoCheckin => ['turno.checkin_solicitado'],
            TurnoStatus::Ativo => ['turno.checkin_solicitado', 'turno.checkin_validado'],
            TurnoStatus::AguardandoCheckout => ['turno.checkin_solicitado', 'turno.checkin_validado', 'turno.checkout_solicitado'],
            TurnoStatus::EmDisputa,
            TurnoStatus::DisputaResolvidaSemPagamento => ['turno.checkin_solicitado', 'turno.checkin_validado', 'turno.checkout_solicitado'],
            TurnoStatus::Finalizado,
            TurnoStatus::FinalizadoAjustado => ['turno.checkin_solicitado', 'turno.checkin_validado', 'turno.checkout_solicitado', 'turno.checkout_validado', 'pagamento.capturado', 'pix.enviado'],
            TurnoStatus::CanceladoPro => [['turno.cancelado', ['lado' => 'pro']]],
            TurnoStatus::CanceladoEmp => [['turno.cancelado', ['lado' => 'emp']]],
            TurnoStatus::NoShowPro => ['turno.no_show_pro'],
        };

        $eventos = [
            ['turno.criado', ['candidatura_id' => $turno->candidatura_id, 'vaga_id' => $turno->vaga_id]],
            // Target próprio + turno_id no payload, como no fluxo real da 058.
            ['aceite_eletronico.emitido', ['turno_id' => $turno->id], 'AceiteEletronicoTurno', $aceite->id],
            ['pagamento.pre_autorizado', ['total_contratante' => (float) $turno->total_contratante]],
            ...$extras,
        ];

        $em = now()->subDays(2);
        foreach ($eventos as $evento) {
            [$action, $payload, $targetType, $targetId] = is_array($evento)
                ? $evento + [2 => 'Turno', 3 => $turno->id]
                : [$evento, [], 'Turno', $turno->id];

            // created_at no INSERT: audit_logs é append-only (trigger + REVOKE).
            AuditLog::query()->forceCreate([
                'actor_id' => $turno->contratante_id,
                'action' => $action,
                'target_type' => $targetType,
                'target_id' => $targetId,
                'payload' => $payload,
                'created_at' => $em = $em->copy()->addMinutes(7),
            ]);
        }
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
