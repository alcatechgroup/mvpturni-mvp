<?php

// STORY-052 — resposta do profissional à edição material (PDR-009).
// CA-7 (confirmar-apos-edicao → pendente + audit), CA-8 (retirar-apos-edicao →
// retirada_por_edicao + audit), CA-11 (bloco `revisao` no detalhe: prazo + diff).

use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Models\AuditLog;
use App\Models\Candidatura;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

/**
 * Cenário: vaga aberta futura cujo valor foi 120 → 150; o profissional viu a v1 (120) e está
 * em revisão. Devolve [profissional, candidatura, vaga].
 *
 * @return array{0:User,1:Candidatura,2:Vaga}
 */
function cenarioRevisao(array $candOver = []): array
{
    $func = Funcao::firstOrCreate(['slug' => 'garcom'], ['nome' => 'Garçom', 'ativo' => true]);
    $contratante = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::create([
        'user_id' => $contratante->id, 'nome_estabelecimento' => 'Bar do Zé',
        'apelido_estabelecimento' => 'Bar do Zé', 'tipo_operacao' => 'bar',
        'cidade' => 'São Paulo', 'uf' => 'SP',
    ]);
    $prof = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->create(['user_id' => $prof->id]);

    $vaga = Vaga::factory()->create([
        'contratante_id' => $contratante->id, 'funcao_id' => $func->id,
        'estado' => VagaEstado::Aberta,
        'data_inicio' => now()->addDays(3)->setTime(19, 0),
        'data_fim' => now()->addDays(3)->setTime(23, 0),
        'valor' => 150.00, 'posicoes' => 2, 'versao_atual' => 2,
    ]);
    // v1 = o que o profissional viu (valor 120).
    $v1 = VagaVersao::factory()->create([
        'vaga_id' => $vaga->id, 'versao' => 1,
        'snapshot' => [
            'funcao_id' => $func->id,
            'data_inicio' => $vaga->data_inicio->toIso8601String(),
            'data_fim' => $vaga->data_fim->toIso8601String(),
            'valor' => 120.00, 'posicoes' => 2, 'observacoes' => null,
            'lat' => (float) $vaga->lat, 'lng' => (float) $vaga->lng,
        ],
    ]);
    $cand = Candidatura::factory()->create(array_merge([
        'vaga_id' => $vaga->id, 'profissional_id' => $prof->id,
        'estado' => CandidaturaEstado::PendenteRevisaoAposEdicao,
        'vaga_versao_id' => $v1->id,
        'revisao_prazo_em' => now()->addHours(20),
    ], $candOver));

    return [$prof, $cand, $vaga];
}

// ───────────────────────── CA-7 — manter ─────────────────────────

test('manter candidatura: pendente_revisao → pendente + audit (CA-7)', function () {
    [$prof, $cand] = cenarioRevisao();

    $this->actingAs($prof)->postJson("/api/candidaturas/{$cand->id}/confirmar-apos-edicao")
        ->assertOk()->assertJsonPath('estado', 'pendente');

    $cand->refresh();
    expect($cand->estado)->toBe(CandidaturaEstado::Pendente);
    expect($cand->revisao_prazo_em)->toBeNull();
    expect(AuditLog::where('action', 'candidatura.mantida_apos_edicao')->where('target_id', $cand->id)->count())->toBe(1);
});

// ───────────────────────── CA-8 — retirar ─────────────────────────

test('retirar candidatura: pendente_revisao → retirada_por_edicao + audit (CA-8)', function () {
    [$prof, $cand] = cenarioRevisao();

    $this->actingAs($prof)->postJson("/api/candidaturas/{$cand->id}/retirar-apos-edicao")
        ->assertOk()->assertJsonPath('estado', 'retirada_por_edicao');

    expect($cand->fresh()->estado)->toBe(CandidaturaEstado::RetiradaPorEdicao);
    expect(AuditLog::where('action', 'candidatura.retirada_por_edicao_voluntaria')->where('target_id', $cand->id)->count())->toBe(1);
});

// ───────────────────────── RBAC + estado inválido ─────────────────────────

test('outro profissional não mantém candidatura alheia → 404 (CA-7)', function () {
    [, $cand] = cenarioRevisao();
    $outro = User::factory()->profissional()->ativo()->create();

    $this->actingAs($outro)->postJson("/api/candidaturas/{$cand->id}/confirmar-apos-edicao")->assertStatus(404);
});

test('contratante não usa endpoints de revisão → 403', function () {
    [, $cand] = cenarioRevisao();
    $contratante = User::factory()->contratante()->ativo()->create();

    $this->actingAs($contratante)->postJson("/api/candidaturas/{$cand->id}/retirar-apos-edicao")->assertStatus(403);
});

test('manter candidatura fora de revisão (pendente) → 409', function () {
    [$prof, $cand] = cenarioRevisao(['estado' => CandidaturaEstado::Pendente, 'revisao_prazo_em' => null]);

    $this->actingAs($prof)->postJson("/api/candidaturas/{$cand->id}/confirmar-apos-edicao")
        ->assertStatus(409)->assertJsonPath('erro', 'estado_invalido');
});

// ───────────────────────── CA-11 — bloco `revisao` no detalhe ─────────────────────────

test('detalhe da vaga inclui bloco revisao com prazo + diff quando candidatura está em revisão (CA-11)', function () {
    [$prof, $cand, $vaga] = cenarioRevisao();

    $res = $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")->assertOk();

    $res->assertJsonPath('candidatura.estado', 'pendente_revisao_apos_edicao');
    expect($res->json('revisao.prazo_em'))->not->toBeNull();
    $diff = collect($res->json('revisao.diff'))->keyBy('campo');
    expect($diff->has('valor'))->toBeTrue();
    expect((float) $diff['valor']['antes'])->toBe(120.0);
    expect((float) $diff['valor']['depois'])->toBe(150.0);
});

test('detalhe sem revisão (candidatura pendente normal) traz revisao=null', function () {
    [$prof, $cand, $vaga] = cenarioRevisao(['estado' => CandidaturaEstado::Pendente, 'revisao_prazo_em' => null]);

    $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")
        ->assertOk()->assertJsonPath('revisao', null);
});

test('diff de função no detalhe resolve nome em vez de id (CA-11)', function () {
    $cozinheiro = Funcao::firstOrCreate(['slug' => 'cozinheiro'], ['nome' => 'Cozinheiro', 'ativo' => true]);
    [$prof, $cand, $vaga] = cenarioRevisao();
    // a vaga atual passou a ser de Cozinheiro; o profissional viu Garçom (na v1).
    $vaga->update(['funcao_id' => $cozinheiro->id]);

    $res = $this->actingAs($prof)->getJson("/api/vagas/{$vaga->id}/detalhe")->assertOk();

    $diff = collect($res->json('revisao.diff'))->keyBy('campo');
    expect($diff['funcao_id']['antes'])->toBe('Garçom');
    expect($diff['funcao_id']['depois'])->toBe('Cozinheiro');
});
