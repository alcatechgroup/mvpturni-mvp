<?php

// STORY-055 / ADR-015 (CA-7) — o TurnosSeeder cria um turno em cada um dos 11 estados,
// é idempotente e anexa aceite imutável a cada turno. Production-safe: sem factories.

use App\Enums\TipoOperacaoPagamento;
use App\Enums\TurnoStatus;
use App\Models\AceiteEletronicoTurno;
use App\Models\AuditLog;
use App\Models\PagamentoOperacao;
use App\Models\Template;
use App\Models\Turno;
use App\Models\User;
use Database\Seeders\AdminUserSeeder;
use Database\Seeders\FuncaoSeeder;
use Database\Seeders\TemplatesContratuaisSeeder;
use Database\Seeders\TurnosSeeder;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/** Dependências do TurnosSeeder (funções + admin autor do template + catálogo PF). */
function seedTurnosComDependencias(): void
{
    test()->seed(AdminUserSeeder::class);
    test()->seed(FuncaoSeeder::class);
    test()->seed(TemplatesContratuaisSeeder::class);
    test()->seed(TurnosSeeder::class);
}

/** Turnos do universo `*.turnos.seed` (a STORY-061 somou o turno PIN em outro contratante). */
function turnosDoSeedPrincipal(): Builder
{
    $contratante = User::where('email', 'contratante.turnos.seed@turni.local')->firstOrFail();

    return Turno::query()->where('contratante_id', $contratante->id);
}

test('seeder cria exatamente um turno em cada um dos 11 estados', function () {
    seedTurnosComDependencias();

    $porEstado = turnosDoSeedPrincipal()->get()->groupBy(fn ($t) => $t->status->value);

    foreach (TurnoStatus::cases() as $status) {
        expect($porEstado->has($status->value))->toBeTrue("faltou turno no estado {$status->value}");
        expect($porEstado[$status->value])->toHaveCount(1);
    }
    expect(turnosDoSeedPrincipal()->count())->toBe(11);
});

test('seeder anexa um aceite imutável a cada turno', function () {
    seedTurnosComDependencias();
    // 11 do universo turnos.seed + PIN (061) + validar (062) + cronômetro (063) + checkout (064)
    // + cancelar-pro/emp + no-show (066) + disputa abertura (094) + disputa fila admin (096).
    expect(AceiteEletronicoTurno::count())->toBe(20);
});

test('seeder é idempotente (rodar 2x não duplica)', function () {
    seedTurnosComDependencias();
    test()->seed(TurnosSeeder::class);
    expect(turnosDoSeedPrincipal()->count())->toBe(11)
        ->and(Turno::count())->toBe(20); // + PIN (061) + validar (062) + cronômetro (063) + checkout (064) + cancelar-pro/emp + no-show (066) + disputa abertura (094) + disputa fila admin (096)
});

test('o turno confirmado do seed demonstra o override de habitualidade (PJ)', function () {
    seedTurnosComDependencias();
    $confirmado = turnosDoSeedPrincipal()->where('status', TurnoStatus::Confirmado)->first();
    expect($confirmado->aceite->habitualidade_override)->toBeTrue();
});

test('o aceite reusa o template PF existente (não cria template novo)', function () {
    seedTurnosComDependencias();
    expect(Template::where('categoria', 'aceite_turno')->count())->toBe(0)
        ->and(AceiteEletronicoTurno::first()->templateVersao->template->slug)->toBe('pf_autonomo_eventual');
});

test('idempotência backfilla a trilha em turnos sem audit log (STORY-060)', function () {
    seedTurnosComDependencias();

    // Turno do contratante seed criado FORA do seeder (sem trilha) — simula um seed
    // anterior à timeline. (Não dá para apagar audit_logs: append-only no banco.)
    $contratante = User::where('email', 'contratante.turnos.seed@turni.local')->firstOrFail();
    $antigo = Turno::factory()->status(TurnoStatus::Confirmado)
        ->create(['contratante_id' => $contratante->id]);
    AceiteEletronicoTurno::factory()->create(['turno_id' => $antigo->id]);

    test()->seed(TurnosSeeder::class); // idempotente: não recria turnos, backfilla a trilha

    // Mesmo filtro do detalhe: target Turno OU aceite referenciando via payload (ADR-018).
    expect(Turno::where('contratante_id', $contratante->id)->count())->toBe(12)
        ->and(AuditLog::query()
            ->where(fn ($q) => $q
                ->where(fn ($q) => $q->where('target_type', 'Turno')->where('target_id', $antigo->id))
                ->orWhere('payload->turno_id', $antigo->id))
            ->orderBy('created_at')->pluck('action')->all())
        ->toBe(['turno.criado', 'aceite_eletronico.emitido', 'pagamento.pre_autorizado']);
});

test('seeder grava trilha de auditoria coerente com o estado (STORY-060)', function () {
    seedTurnosComDependencias();

    // Base em todo turno: criado + aceite + pré-autorização.
    $confirmado = Turno::where('status', TurnoStatus::Confirmado)->first();
    $acoesDoTurno = fn ($turno) => AuditLog::query()
        ->where(fn ($q) => $q
            ->where(fn ($q) => $q->where('target_type', 'Turno')->where('target_id', $turno->id))
            ->orWhere('payload->turno_id', $turno->id))
        ->orderBy('created_at')
        ->pluck('action')
        ->all();

    expect($acoesDoTurno($confirmado))
        ->toBe(['turno.criado', 'aceite_eletronico.emitido', 'pagamento.pre_autorizado']);

    // Finalizado tem o ciclo completo até o Pix.
    $finalizado = Turno::where('status', TurnoStatus::Finalizado)->first();
    expect($acoesDoTurno($finalizado))->toBe([
        'turno.criado', 'aceite_eletronico.emitido', 'pagamento.pre_autorizado',
        'turno.checkin_solicitado', 'turno.checkin_validado',
        'turno.checkout_solicitado', 'turno.checkout_validado',
        'pagamento.capturado', 'pix.enviado',
    ]);

    // Cancelado registra o lado no payload (consumido pela timeline da 060/066).
    $canceladoEmp = Turno::where('status', TurnoStatus::CanceladoEmp)->first();
    $cancelado = AuditLog::where('action', 'turno.cancelado')
        ->where('target_id', $canceladoEmp->id)->first();
    expect($cancelado->payload['lado'])->toBe('emp');
});

test('STORY-061: seeder cria o turno PIN (confirmado, na janela) com usuários exclusivos', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.pin.seed@turni.local')->first();
    expect($pro)->not->toBeNull();

    $turno = Turno::where('profissional_id', $pro->id)->first();
    expect($turno)->not->toBeNull()
        ->and($turno->status)->toBe(TurnoStatus::Confirmado)
        // Dentro da janela default (−30min/+2h): início ~15min à frente.
        ->and($turno->data_inicio->isAfter(now()))->toBeTrue()
        ->and($turno->data_inicio->isBefore(now()->addMinutes(30)))->toBeTrue()
        ->and((float) $turno->vaga->lat)->toBe(-23.55)
        ->and($turno->aceite)->not->toBeNull();
});

test('STORY-061: reseed renova a janela do turno PIN sem duplicar', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.pin.seed@turni.local')->first();
    $turno = Turno::where('profissional_id', $pro->id)->first();

    // Envelhece a janela (simula homolog dias depois) e re-seeda.
    $turno->forceFill([
        'data_inicio' => now()->subDays(3),
        'data_fim' => now()->subDays(3)->addHours(6),
    ])->save();

    test()->seed(TurnosSeeder::class);

    expect(Turno::where('profissional_id', $pro->id)->count())->toBe(1);
    expect($turno->fresh()->data_inicio->isAfter(now()))->toBeTrue();
});

test('STORY-062: seeder cria o turno de validação com usuários exclusivos *.validar.seed', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.validar.seed@turni.local')->first();
    expect($pro)->not->toBeNull();

    $turno = Turno::where('profissional_id', $pro->id)->first();
    expect($turno)->not->toBeNull()
        ->and($turno->status)->toBe(TurnoStatus::Confirmado)
        ->and($turno->data_inicio->isAfter(now()))->toBeTrue()
        ->and((float) $turno->vaga->lat)->toBe(-23.55)
        ->and($turno->aceite)->not->toBeNull();
});

test('STORY-062: turno validar consumido (ativo) → reseed cria um NOVO confirmado na janela', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.validar.seed@turni.local')->first();
    $consumido = Turno::where('profissional_id', $pro->id)->first();
    // E2E validou o PIN: ativo (não volta — máquina de estados; o trigger só guarda UPDATE
    // de status, então o caminho legal são as transições reais).
    $consumido->transitionTo(TurnoStatus::AguardandoCheckin);
    $consumido->transitionTo(TurnoStatus::Ativo);

    test()->seed(TurnosSeeder::class);

    $turnos = Turno::where('profissional_id', $pro->id)->orderBy('created_at')->get();
    expect($turnos)->toHaveCount(2)
        ->and($turnos[0]->status)->toBe(TurnoStatus::Ativo)        // histórico fica
        ->and($turnos[1]->status)->toBe(TurnoStatus::Confirmado)   // novo, pronto p/ E2E
        ->and($turnos[1]->data_inicio->isAfter(now()))->toBeTrue()
        ->and($turnos[1]->aceite)->not->toBeNull();

    // Reseed seguinte só renova a janela do novo (não duplica de novo).
    test()->seed(TurnosSeeder::class);
    expect(Turno::where('profissional_id', $pro->id)->count())->toBe(2);
});

test('STORY-064: seeder cria o turno do ciclo de check-out com usuários exclusivos *.checkout.seed', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.checkout.seed@turni.local')->first();
    expect($pro)->not->toBeNull();

    $turno = Turno::where('profissional_id', $pro->id)->first();
    expect($turno)->not->toBeNull()
        ->and($turno->status)->toBe(TurnoStatus::Confirmado)
        ->and($turno->data_inicio->isAfter(now()))->toBeTrue()
        ->and((float) $turno->vaga->lat)->toBe(-23.55)
        ->and($turno->aceite)->not->toBeNull();
});

test('STORY-064: turno checkout consumido (finalizado) → reseed cria um NOVO confirmado na janela', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.checkout.seed@turni.local')->first();
    $consumido = Turno::where('profissional_id', $pro->id)->first();
    // E2E percorreu o ciclo completo: finalizado é TERMINAL (não volta).
    $consumido->transitionTo(TurnoStatus::AguardandoCheckin);
    $consumido->transitionTo(TurnoStatus::Ativo);
    $consumido->transitionTo(TurnoStatus::AguardandoCheckout);
    $consumido->transitionTo(TurnoStatus::Finalizado);

    test()->seed(TurnosSeeder::class);

    // Ordena por `id` (UUIDv7 — ordenável no tempo com precisão sub-segundo; created_at
    // empata quando os dois nascem no mesmo segundo do teste — ADR-018).
    $turnos = Turno::where('profissional_id', $pro->id)->orderBy('id')->get();
    expect($turnos)->toHaveCount(2)
        ->and($turnos[0]->status)->toBe(TurnoStatus::Finalizado)   // histórico fica
        ->and($turnos[1]->status)->toBe(TurnoStatus::Confirmado)   // novo, pronto p/ E2E
        ->and($turnos[1]->data_inicio->isAfter(now()))->toBeTrue()
        ->and($turnos[1]->aceite)->not->toBeNull();

    // Run interrompido no meio do ciclo (aguardando_checkout) também recria.
    $turnos[1]->transitionTo(TurnoStatus::AguardandoCheckin);
    $turnos[1]->transitionTo(TurnoStatus::Ativo);
    test()->seed(TurnosSeeder::class);
    expect(Turno::where('profissional_id', $pro->id)->count())->toBe(3);
});

test('STORY-063: seeder cria o turno cronômetro (ativo, ~35min decorridos) com usuários exclusivos', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.cronometro.seed@turni.local')->first();
    expect($pro)->not->toBeNull();

    $turno = Turno::where('profissional_id', $pro->id)->first();
    expect($turno)->not->toBeNull()
        ->and($turno->status)->toBe(TurnoStatus::Ativo)
        ->and($turno->check_in_at->isBefore(now()->subMinutes(30)))->toBeTrue()
        ->and($turno->check_in_at->isAfter(now()->subMinutes(40)))->toBeTrue()
        ->and($turno->data_fim->isAfter(now()))->toBeTrue() // formato HH:MM:SS (turno longo)
        ->and($turno->aceite)->not->toBeNull();
});

test('STORY-063: reseed renova o check_in_at do turno cronômetro sem duplicar (leitura pura)', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.cronometro.seed@turni.local')->first();
    $turno = Turno::where('profissional_id', $pro->id)->first();

    // Envelhece o cenário (homolog dias depois) e re-seeda.
    $turno->forceFill([
        'data_inicio' => now()->subDays(3),
        'data_fim' => now()->subDays(3)->addHours(6),
        'check_in_at' => now()->subDays(3),
    ])->save();

    test()->seed(TurnosSeeder::class);

    expect(Turno::where('profissional_id', $pro->id)->count())->toBe(1);
    $fresh = $turno->fresh();
    expect($fresh->status)->toBe(TurnoStatus::Ativo)
        ->and($fresh->check_in_at->isAfter(now()->subMinutes(40)))->toBeTrue()
        ->and($fresh->data_fim->isAfter(now()))->toBeTrue();
});

test('STORY-062: turno PIN (061) consumido NÃO é recriado (recriação é só do validar)', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.pin.seed@turni.local')->first();
    $turnoPin = Turno::where('profissional_id', $pro->id)->first();
    $turnoPin->transitionTo(TurnoStatus::AguardandoCheckin);
    $turnoPin->transitionTo(TurnoStatus::Ativo);

    test()->seed(TurnosSeeder::class);

    expect(Turno::where('profissional_id', $pro->id)->count())->toBe(1);
});

// ──────────────────────────────────────────────────────────────
// STORY-066 — pares de cancelamento + no-show vencido
// ──────────────────────────────────────────────────────────────

test('STORY-066: pares cancelar-pro/emp nascem confirmados na janela; no-show nasce VENCIDO', function () {
    seedTurnosComDependencias();

    foreach (['cancelarpro', 'cancelaremp'] as $par) {
        $pro = User::where('email', "profissional.{$par}.seed@turni.local")->first();
        $turno = Turno::where('profissional_id', $pro->id)->first();
        expect($turno->status)->toBe(TurnoStatus::Confirmado, "{$par} deveria estar confirmado")
            ->and($turno->data_inicio->isAfter(now()))->toBeTrue();
    }

    $proNoShow = User::where('email', 'profissional.noshow.seed@turni.local')->first();
    $vencido = Turno::where('profissional_id', $proNoShow->id)->first();
    expect($vencido->status)->toBe(TurnoStatus::Confirmado)
        // início há 3h > X=2h: o cron transita na primeira rodada após o seed
        ->and($vencido->data_inicio->isBefore(now()->subHours(2)))->toBeTrue();
});

test('STORY-066: cron transita o no-show seed e o turno consumido é recriado vencido no próximo seed', function () {
    seedTurnosComDependencias();

    test()->artisan('turnos:detectar-no-show')->assertSuccessful();

    $pro = User::where('email', 'profissional.noshow.seed@turni.local')->first();
    expect(Turno::where('profissional_id', $pro->id)->first()->status)->toBe(TurnoStatus::NoShowPro);

    // Próximo seed: par consumido (terminal) → recria um novo turno vencido.
    test()->seed(TurnosSeeder::class);
    expect(Turno::where('profissional_id', $pro->id)->count())->toBe(2)
        ->and(
            Turno::where('profissional_id', $pro->id)
                ->where('status', TurnoStatus::Confirmado)->first()
                ->data_inicio->isBefore(now()->subHours(2)),
        )->toBeTrue();
});

// ──────────────────────────────────────────────────────────────
// STORY-094 — par de disputa em aguardando_checkout
// ──────────────────────────────────────────────────────────────

test('STORY-094: seeder cria o turno em aguardando_checkout com usuários exclusivos *.disputa.seed', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.disputa.seed@turni.local')->first();
    expect($pro)->not->toBeNull();

    $turno = Turno::where('profissional_id', $pro->id)->first();
    expect($turno)->not->toBeNull()
        ->and($turno->status)->toBe(TurnoStatus::AguardandoCheckout)
        ->and($turno->check_in_at)->not->toBeNull()
        ->and($turno->aceite)->not->toBeNull()
        // Pré-autorização sintética mantida (a disputa NÃO libera o bloqueio — ADR-020).
        ->and(
            PagamentoOperacao::where('turno_id', $turno->id)
                ->where('tipo_operacao', TipoOperacaoPagamento::PreAutorizacao)->exists(),
        )->toBeTrue();
});

test('STORY-094: turno disputa consumido (em_disputa) → reseed cria um NOVO aguardando_checkout', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.disputa.seed@turni.local')->first();
    $consumido = Turno::where('profissional_id', $pro->id)->first();
    // E2E abriu a disputa: aguardando_checkout → em_disputa (não volta — máquina de estados).
    $consumido->transitionTo(TurnoStatus::EmDisputa);

    test()->seed(TurnosSeeder::class);

    $turnos = Turno::where('profissional_id', $pro->id)->orderBy('id')->get();
    expect($turnos)->toHaveCount(2)
        ->and($turnos[0]->status)->toBe(TurnoStatus::EmDisputa)            // histórico fica
        ->and($turnos[1]->status)->toBe(TurnoStatus::AguardandoCheckout)   // novo, pronto p/ E2E
        ->and($turnos[1]->aceite)->not->toBeNull();

    // Reseed seguinte só renova a janela do novo (não duplica).
    test()->seed(TurnosSeeder::class);
    expect(Turno::where('profissional_id', $pro->id)->count())->toBe(2);
});

// ──────────────────────────────────────────────────────────────
// STORY-096 — turno em em_disputa para a fila do backoffice
// ──────────────────────────────────────────────────────────────

test('STORY-096: seeder cria o turno em em_disputa com usuários exclusivos *.disputa096.seed e trilha de abertura', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.disputa096.seed@turni.local')->first();
    expect($pro)->not->toBeNull();

    $turno = Turno::where('profissional_id', $pro->id)->first();
    expect($turno)->not->toBeNull()
        ->and($turno->status)->toBe(TurnoStatus::EmDisputa)
        ->and($turno->disputa['justificativa_contratante'] ?? null)->not->toBeNull()
        ->and($turno->disputa['resolucao'])->toBeNull() // disputa AINDA aberta (chave presente, valor null)
        ->and($turno->aceite)->not->toBeNull()
        // Pré-autorização sintética mantida (a disputa NÃO libera o bloqueio — ADR-020).
        ->and(
            PagamentoOperacao::where('turno_id', $turno->id)
                ->where('tipo_operacao', TipoOperacaoPagamento::PreAutorizacao)->exists(),
        )->toBeTrue()
        // Trilha de abertura registrada (caso do admin — ADR-020 Decisão 6).
        ->and(
            \App\Models\AuditLog::where('target_id', $turno->id)
                ->where('action', 'turno.disputa_aberta')->exists(),
        )->toBeTrue();
});

test('STORY-096: turno disputa096 consumido (finalizado) → reseed cria um NOVO em_disputa', function () {
    seedTurnosComDependencias();

    $pro = User::where('email', 'profissional.disputa096.seed@turni.local')->first();
    $consumido = Turno::where('profissional_id', $pro->id)->first();
    // O admin resolveu "pagar integral": em_disputa → finalizado (não volta — máquina de estados).
    $consumido->transitionTo(TurnoStatus::Finalizado);

    test()->seed(TurnosSeeder::class);

    $turnos = Turno::where('profissional_id', $pro->id)->orderBy('id')->get();
    expect($turnos)->toHaveCount(2)
        ->and($turnos[0]->status)->toBe(TurnoStatus::Finalizado) // histórico fica
        ->and($turnos[1]->status)->toBe(TurnoStatus::EmDisputa);  // novo, pronto p/ E2E

    // Reseed seguinte só renova a abertura do novo (não duplica).
    test()->seed(TurnosSeeder::class);
    expect(Turno::where('profissional_id', $pro->id)->count())->toBe(2);
});
