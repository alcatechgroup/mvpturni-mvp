<?php

// STORY-044 / ADR-013 Decisão 5 (CA-6) — os eventos de ciclo de vida de vaga e
// candidatura são registráveis na trilha geral audit_logs (ator = qualquer usuário),
// distinta do admin_audit_log (ações de admin, ADR-009).

use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

dataset('eventos_de_dominio', [
    ['vaga.criada', 'Vaga', ['funcao_id' => 3, 'posicoes' => 2]],
    ['vaga.editada_material', 'Vaga', ['versao' => 2, 'campos' => ['valor', 'data_inicio']]],
    ['vaga.cancelada', 'Vaga', ['candidaturas_pendentes' => 4]],
    ['candidatura.criada', 'Candidatura', ['vaga_id' => 10]],
    ['candidatura.aprovada', 'Candidatura', ['vaga_id' => 10, 'posicoes_restantes' => 1]],
    ['candidatura.retirada_por_edicao', 'Candidatura', ['vaga_id' => 10, 'versao' => 2]],
]);

test('cada evento de domínio do CA-6 é gravável com ator, alvo e payload', function (string $action, string $targetType, array $payload) {
    $ator = User::factory()->contratante()->ativo()->create();

    $log = AuditLog::create([
        'actor_id' => $ator->id,
        'action' => $action,
        'target_type' => $targetType,
        'target_id' => 42,
        'payload' => $payload,
    ]);

    $log->refresh();
    expect($log->action)->toBe($action)
        ->and($log->target_type)->toBe($targetType)
        // toEqual (==): jsonb não preserva a ordem das chaves do objeto; comparar por
        // par chave/valor, não por identidade ordenada.
        ->and($log->payload)->toEqual($payload)
        ->and($log->actor->id)->toBe($ator->id);
})->with('eventos_de_dominio');

test('payload é casteado para array', function () {
    $log = AuditLog::create(['action' => 'vaga.criada', 'payload' => ['x' => 1]]);
    expect($log->fresh()->payload)->toBeArray()->toBe(['x' => 1]);
});
