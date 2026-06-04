<?php

// STORY-055 / ADR-015 (CA-7) — o TurnosSeeder cria um turno em cada um dos 11 estados,
// é idempotente e anexa aceite imutável a cada turno. Production-safe: sem factories.

use App\Enums\TurnoStatus;
use App\Models\AceiteEletronicoTurno;
use App\Models\Template;
use App\Models\Turno;
use Database\Seeders\AdminUserSeeder;
use Database\Seeders\FuncaoSeeder;
use Database\Seeders\TemplatesContratuaisSeeder;
use Database\Seeders\TurnosSeeder;
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

test('seeder cria exatamente um turno em cada um dos 11 estados', function () {
    seedTurnosComDependencias();

    $porEstado = Turno::query()->get()->groupBy(fn ($t) => $t->status->value);

    foreach (TurnoStatus::cases() as $status) {
        expect($porEstado->has($status->value))->toBeTrue("faltou turno no estado {$status->value}");
        expect($porEstado[$status->value])->toHaveCount(1);
    }
    expect(Turno::count())->toBe(11);
});

test('seeder anexa um aceite imutável a cada turno', function () {
    seedTurnosComDependencias();
    expect(AceiteEletronicoTurno::count())->toBe(11);
});

test('seeder é idempotente (rodar 2x não duplica)', function () {
    seedTurnosComDependencias();
    test()->seed(TurnosSeeder::class);
    expect(Turno::count())->toBe(11);
});

test('o turno confirmado do seed demonstra o override de habitualidade (PJ)', function () {
    seedTurnosComDependencias();
    $confirmado = Turno::where('status', TurnoStatus::Confirmado)->first();
    expect($confirmado->aceite->habitualidade_override)->toBeTrue();
});

test('o aceite reusa o template PF existente (não cria template novo)', function () {
    seedTurnosComDependencias();
    expect(Template::where('categoria', 'aceite_turno')->count())->toBe(0)
        ->and(AceiteEletronicoTurno::first()->templateVersao->template->slug)->toBe('pf_autonomo_eventual');
});
