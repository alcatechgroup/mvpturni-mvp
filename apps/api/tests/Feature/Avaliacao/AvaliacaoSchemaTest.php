<?php

// STORY-085 / ADR-019 Decisão 1 (CA-1) — invariantes duras de `avaliacoes` no banco:
// uma avaliação por direção/turno (UNIQUE), estrelas obrigatórias 1–5 (CHECK), ninguém se
// autoavalia (CHECK autor <> avaliado). São à prova de SQL cru, não disciplina de aplicação.

use App\Enums\AvaliacaoDirecao;
use App\Enums\TurnoStatus;
use App\Models\Avaliacao;
use App\Models\Turno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

/** Insere uma linha de avaliação via SQL cru — exercita o banco, não o model (CA-1). */
function inserirAvaliacao(Turno $turno, array $overrides = []): void
{
    DB::table('avaliacoes')->insert(array_merge([
        'id' => Str::uuid7()->toString(),
        'turno_id' => $turno->id,
        'autor_id' => $turno->contratante_id,
        'avaliado_id' => $turno->profissional_id,
        'direcao' => AvaliacaoDirecao::ContratanteParaProfissional->value,
        'estrelas' => 5,
        'comentario' => null,
        'created_at' => now(),
        'updated_at' => now(),
    ], $overrides));
}

test('migração cria a tabela avaliacoes com as colunas do ADR-019', function () {
    expect(Schema::hasColumns('avaliacoes', [
        'id', 'turno_id', 'autor_id', 'avaliado_id', 'direcao',
        'estrelas', 'comentario', 'created_at', 'updated_at',
    ]))->toBeTrue();
});

test('UNIQUE(turno_id, direcao): rejeita a 2ª avaliação na mesma direção do mesmo turno', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    inserirAvaliacao($turno);

    expect(fn () => inserirAvaliacao($turno))->toThrow(Exception::class);
});

test('UNIQUE(turno_id, direcao): aceita uma avaliação em cada direção do mesmo turno', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();

    inserirAvaliacao($turno); // contratante → profissional
    inserirAvaliacao($turno, [
        'id' => Str::uuid7()->toString(),
        'autor_id' => $turno->profissional_id,
        'avaliado_id' => $turno->contratante_id,
        'direcao' => AvaliacaoDirecao::ProfissionalParaContratante->value,
    ]);

    expect(DB::table('avaliacoes')->where('turno_id', $turno->id)->count())->toBe(2);
});

test('CHECK estrelas BETWEEN 1 AND 5: rejeita 0 e 6', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();

    expect(fn () => inserirAvaliacao($turno, ['estrelas' => 0]))->toThrow(Exception::class);
    expect(fn () => inserirAvaliacao($turno, ['estrelas' => 6]))->toThrow(Exception::class);
});

test('estrelas é NOT NULL (obrigatória — PDR-005)', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();

    expect(fn () => inserirAvaliacao($turno, ['estrelas' => null]))->toThrow(Exception::class);
});

test('CHECK autor <> avaliado: ninguém se autoavalia', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();

    expect(fn () => inserirAvaliacao($turno, ['avaliado_id' => $turno->contratante_id]))
        ->toThrow(Exception::class);
});

test('relations do model Avaliacao resolvem turno, autor e avaliado', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();
    $avaliacao = Avaliacao::create([
        'turno_id' => $turno->id,
        'autor_id' => $turno->contratante_id,
        'avaliado_id' => $turno->profissional_id,
        'direcao' => AvaliacaoDirecao::ContratanteParaProfissional,
        'estrelas' => 5,
    ]);

    expect($avaliacao->turno->id)->toBe($turno->id)
        ->and($avaliacao->autor->id)->toBe($turno->contratante_id)
        ->and($avaliacao->avaliado->id)->toBe($turno->profissional_id);
});

test('Avaliacao usa UUIDv7 e persiste via Eloquent', function () {
    $turno = Turno::factory()->status(TurnoStatus::Finalizado)->create();

    $avaliacao = Avaliacao::create([
        'turno_id' => $turno->id,
        'autor_id' => $turno->contratante_id,
        'avaliado_id' => $turno->profissional_id,
        'direcao' => AvaliacaoDirecao::ContratanteParaProfissional,
        'estrelas' => 4,
        'comentario' => 'Bom trabalho',
    ]);

    expect($avaliacao->id)->toBeString()
        ->and($avaliacao->direcao)->toBe(AvaliacaoDirecao::ContratanteParaProfissional)
        ->and($avaliacao->estrelas)->toBe(4);
});
