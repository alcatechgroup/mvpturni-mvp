<?php

// STORY-086 / ADR-019 D5 (F2) — fail-secure do lado profissional: se a consulta de pendência
// lança, o gate de candidatura BLOQUEIA e o julgamento booleano do feed (podeCandidatar) trata
// como bloqueado. Unidade pura (sem banco): a fonte de pendência é um stub que lança.

use App\Domain\Avaliacao\AvaliacoesPendentesProfissional;
use App\Domain\Candidatura\Gates\GateAvaliacao;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;

/** Fonte de pendência que sempre falha (erro de infra simulado). */
function pendenciasQueFalham(): AvaliacoesPendentesProfissional
{
    return new class extends AvaliacoesPendentesProfissional
    {
        public function turnoPendente(User $profissional): ?Turno
        {
            throw new RuntimeException('db down');
        }
    };
}

test('gate de candidatura bloqueia quando a consulta de pendência falha (fail-secure)', function () {
    $gate = new GateAvaliacao(pendenciasQueFalham());

    $resultado = $gate->verificar(new User, new Vaga);

    expect($resultado->bloqueado)->toBeTrue()
        ->and($resultado->erro)->toBe('gate_avaliacao')
        ->and($resultado->mensagem)->toBe('Avalie seu último turno para se candidatar.')
        ->and($resultado->detalhe)->toBe(['turno_id' => null]);
});

test('podeCandidatar retorna false quando a consulta falha (fail-secure do feed)', function () {
    expect(pendenciasQueFalham()->podeCandidatar(new User))->toBeFalse();
});
