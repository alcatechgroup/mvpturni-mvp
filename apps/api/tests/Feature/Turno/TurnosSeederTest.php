<?php

// STORY-055 / ADR-015 (CA-7) — o TurnosSeeder cria um turno em cada um dos 11 estados,
// é idempotente e anexa aceite imutável a cada turno.

use App\Enums\TurnoStatus;
use App\Models\AceiteEletronicoTurno;
use App\Models\Turno;
use Database\Seeders\TurnosSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('seeder cria exatamente um turno em cada um dos 11 estados', function () {
    $this->seed(TurnosSeeder::class);

    $porEstado = Turno::query()->get()->groupBy(fn ($t) => $t->status->value);

    foreach (TurnoStatus::cases() as $status) {
        expect($porEstado->has($status->value))->toBeTrue("faltou turno no estado {$status->value}");
        expect($porEstado[$status->value])->toHaveCount(1);
    }
    expect(Turno::count())->toBe(11);
});

test('seeder anexa um aceite imutável a cada turno', function () {
    $this->seed(TurnosSeeder::class);
    expect(AceiteEletronicoTurno::count())->toBe(11);
});

test('seeder é idempotente (rodar 2x não duplica)', function () {
    $this->seed(TurnosSeeder::class);
    $this->seed(TurnosSeeder::class);
    expect(Turno::count())->toBe(11);
});

test('o turno confirmado do seed demonstra o override de habitualidade (PJ)', function () {
    $this->seed(TurnosSeeder::class);
    $confirmado = Turno::where('status', TurnoStatus::Confirmado)->first();
    expect($confirmado->aceite->habitualidade_override)->toBeTrue();
});
