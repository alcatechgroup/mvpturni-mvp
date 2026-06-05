<?php

// STORY-055 / ADR-015 (CA-7) — o TurnosSeeder cria um turno em cada um dos 11 estados,
// é idempotente e anexa aceite imutável a cada turno. Production-safe: sem factories.

use App\Enums\TurnoStatus;
use App\Models\AceiteEletronicoTurno;
use App\Models\AuditLog;
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
    // 11 do universo turnos.seed + 1 do turno PIN (STORY-061).
    expect(AceiteEletronicoTurno::count())->toBe(12);
});

test('seeder é idempotente (rodar 2x não duplica)', function () {
    seedTurnosComDependencias();
    test()->seed(TurnosSeeder::class);
    expect(turnosDoSeedPrincipal()->count())->toBe(11)
        ->and(Turno::count())->toBe(12); // + turno PIN (STORY-061)
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
