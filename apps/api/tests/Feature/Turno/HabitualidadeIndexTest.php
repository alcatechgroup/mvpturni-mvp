<?php

// STORY-055 / ADR-015 (CA-5) — o índice composto de habitualidade (ADR-006) serve o caminho
// de aceite: contagem por (estabelecimento, profissional) na semana corrida da vaga-alvo.
// Guard automatizado: com seqscan desabilitado, o plano usa `idx_turnos_habitualidade`
// (prova que o índice cobre o shape da query). O EXPLAIN ANALYZE com volume está na ADR-015.

use App\Models\Turno;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

uses(RefreshDatabase::class);

test('a consulta de habitualidade usa idx_turnos_habitualidade', function () {
    $contratante = User::factory()->contratante()->ativo()->create();
    $profissional = User::factory()->profissional()->ativo()->create();

    // Alguns turnos do par na semana (o suficiente para a query ter o que contar).
    Turno::factory()->count(3)->create([
        'contratante_id' => $contratante->id,
        'estabelecimento_id' => $contratante->id,
        'profissional_id' => $profissional->id,
        'data_inicio' => Carbon::parse('2026-06-08 18:00:00'), // segunda
        'data_fim' => Carbon::parse('2026-06-08 23:00:00'),
    ]);

    $inicioSemana = '2026-06-08 00:00:00';
    $fimSemana = '2026-06-14 23:59:59';

    // Determinístico: força o planejador a preferir índice a seqscan (conjunto de teste é
    // pequeno demais para o custo-baseado escolher índice sozinho — o que importa aqui é que
    // o índice COBRE o shape da query).
    DB::statement('SET LOCAL enable_seqscan = off');

    $plano = DB::select(
        'EXPLAIN (FORMAT JSON) SELECT count(*) FROM turnos
         WHERE estabelecimento_id = ? AND profissional_id = ? AND data_inicio BETWEEN ? AND ?',
        [$contratante->id, $profissional->id, $inicioSemana, $fimSemana],
    );

    $json = $plano[0]->{'QUERY PLAN'};
    expect($json)->toContain('idx_turnos_habitualidade');
});
