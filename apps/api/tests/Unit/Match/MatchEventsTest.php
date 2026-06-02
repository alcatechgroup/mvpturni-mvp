<?php

// STORY-045 / ADR-014 (CA-6) — os 4 eventos de telemetria saem como log JSON
// estruturado (ADR-008), sem tabela própria. Capturamos o log com Log::spy e
// asseveramos o nome exato do evento e o payload mínimo.

use App\Domain\Match\MatchCalculator;
use App\Domain\Match\MatchInput;
use App\Support\Telemetry\MatchEvents;
use App\Support\Telemetry\MotivoFiltro;
use Illuminate\Support\Facades\Log;

function scoreExemplo(): \App\Domain\Match\MatchScore
{
    return (new MatchCalculator)->calcular(new MatchInput(
        funcaoVagaId: 7, funcaoPrimariaProfId: 7, funcoesSecundariasProfIds: [],
        distanciaKm: 2.0, raioMaxKm: 8, scoreHistorico: 5.0, turnosRealizados: 30, nivel: 'Elite',
    ));
}

test('feed.vaga_apresentada loga score e componentes (CA-6)', function () {
    Log::spy();

    MatchEvents::vagaApresentada(vagaId: 10, profissionalId: 20, score: scoreExemplo());

    Log::shouldHaveReceived('info')->once()->withArgs(function (string $event, array $ctx) {
        return $event === 'feed.vaga_apresentada'
            && $ctx['vaga_id'] === 10
            && $ctx['profissional_id'] === 20
            && $ctx['score_total'] === 100
            && $ctx['componentes']['funcao'] === 40;
    });
});

test('feed.vaga_filtrada loga o motivo do filtro (CA-6)', function () {
    Log::spy();

    MatchEvents::vagaFiltrada(vagaId: 11, profissionalId: 21, motivo: MotivoFiltro::ForaRaio);

    Log::shouldHaveReceived('info')->once()->withArgs(function (string $event, array $ctx) {
        return $event === 'feed.vaga_filtrada'
            && $ctx['vaga_id'] === 11
            && $ctx['profissional_id'] === 21
            && $ctx['motivo_filtro'] === 'fora_raio';
    });
});

test('match.candidatura_enviada registra o score do momento (CA-6)', function () {
    Log::spy();

    MatchEvents::candidaturaEnviada(vagaId: 12, profissionalId: 22, candidaturaId: 500, score: scoreExemplo());

    Log::shouldHaveReceived('info')->once()->withArgs(function (string $event, array $ctx) {
        return $event === 'match.candidatura_enviada'
            && $ctx['candidatura_id'] === 500
            && $ctx['score_total'] === 100
            && isset($ctx['componentes']);
    });
});

test('match.candidatura_aprovada registra o score do momento (CA-6)', function () {
    Log::spy();

    MatchEvents::candidaturaAprovada(vagaId: 13, profissionalId: 23, candidaturaId: 501, score: scoreExemplo());

    Log::shouldHaveReceived('info')->once()->withArgs(function (string $event, array $ctx) {
        return $event === 'match.candidatura_aprovada'
            && $ctx['candidatura_id'] === 501
            && $ctx['score_total'] === 100;
    });
});

test('os 4 motivos de filtro têm os rótulos canônicos da ADR (CA-6)', function () {
    expect(array_map(fn ($c) => $c->value, MotivoFiltro::cases()))
        ->toBe(['funcao_fora', 'fora_raio', 'conflito_horario', 'gate_avaliacao']);
});
