<?php

// STORY-055 / ADR-015 (CA-3) — imutabilidade do AceiteEletronicoTurno: insert-only,
// garantida no banco por trigger BEFORE UPDATE/DELETE + REVOKE (padrão ADR-010).

use App\Models\AceiteEletronicoTurno;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

test('aceite de turno aceita INSERT e gera UUID', function () {
    $aceite = AceiteEletronicoTurno::factory()->create();
    expect(Str::isUuid($aceite->id))->toBeTrue();
});

test('aceite de turno é imutável — UPDATE (SQL) lança exceção', function () {
    $aceite = AceiteEletronicoTurno::factory()->create();
    expect(fn () => DB::statement('UPDATE aceites_eletronicos_turno SET fingerprint = ? WHERE id = ?', ['x', $aceite->id]))
        ->toThrow(Exception::class);
});

test('aceite de turno é imutável — DELETE (SQL) lança exceção', function () {
    $aceite = AceiteEletronicoTurno::factory()->create();
    expect(fn () => DB::statement('DELETE FROM aceites_eletronicos_turno WHERE id = ?', [$aceite->id]))
        ->toThrow(Exception::class);
});

test('aceite de turno é imutável — Eloquent update() lança exceção', function () {
    $aceite = AceiteEletronicoTurno::factory()->create();
    expect(fn () => $aceite->update(['fingerprint' => 'y']))->toThrow(Exception::class);
});

test('cláusula de override de habitualidade é persistida (PDR-002)', function () {
    $aceite = AceiteEletronicoTurno::factory()->comOverrideHabitualidade()->create();
    $fresh = $aceite->fresh();
    expect($fresh->habitualidade_override)->toBeTrue()
        ->and($fresh->dados_renderizados['habitualidade.override_aceito'])->toBeTrue();
});

test('aceite referencia o turno, a template_versao e carrega o documento autocontido', function () {
    $aceite = AceiteEletronicoTurno::factory()->create();
    expect($aceite->turno)->not->toBeNull()
        ->and($aceite->templateVersao)->not->toBeNull()
        ->and($aceite->conteudo_renderizado)->toBeString()->not->toBeEmpty();
});
