<?php

// STORY-052 CA-13 — E2E do ciclo de edição material (PDR-009) contra o banco + endpoints reais:
// contratante edita a vaga (muda valor) com 2 candidatos pendentes → as duas candidaturas viram
// `pendente_revisao_apos_edicao` → profissional 1 MANTÉM → profissional 2 NÃO age → o cron roda
// com o relógio adiantado (>24h) → profissional 2 sai como `retirada_por_edicao`, profissional 1
// segue `pendente`. Exercita PATCH /vagas/{id}, POST confirmar-apos-edicao e o command do cron.

use App\Enums\CandidaturaEstado;
use App\Models\Candidatura;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('ciclo completo: edita → 2 em revisão → 1 mantém, 1 some pelo cron (CA-13)', function () {
    // ─── seed: contratante dono + vaga aberta (valor 120) + v1 + 2 profissionais candidatos ───
    $func = Funcao::firstOrCreate(['slug' => 'garcom'], ['nome' => 'Garçom', 'ativo' => true]);
    $dono = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::create([
        'user_id' => $dono->id, 'nome_estabelecimento' => 'Bar do Zé',
        'tipo_operacao' => 'bar', 'cidade' => 'São Paulo', 'uf' => 'SP',
    ]);

    $vaga = Vaga::factory()->create([
        'contratante_id' => $dono->id, 'funcao_id' => $func->id,
        'data_inicio' => now()->addDays(10)->setTime(18, 0),
        'data_fim' => now()->addDays(10)->setTime(23, 0),
        'valor' => 120.00, 'posicoes' => 2, 'versao_atual' => 1,
    ]);
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

    $prof1 = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->create(['user_id' => $prof1->id]);
    $prof2 = User::factory()->profissional()->ativo()->create();
    ProfissionalProfile::factory()->create(['user_id' => $prof2->id]);

    $c1 = Candidatura::factory()->create([
        'vaga_id' => $vaga->id, 'profissional_id' => $prof1->id,
        'estado' => CandidaturaEstado::Pendente, 'vaga_versao_id' => $v1->id,
    ]);
    $c2 = Candidatura::factory()->create([
        'vaga_id' => $vaga->id, 'profissional_id' => $prof2->id,
        'estado' => CandidaturaEstado::Pendente, 'vaga_versao_id' => $v1->id,
    ]);

    // ─── 1) contratante edita o valor (120 → 150) — edição material com 2 pendentes ───
    $this->actingAs($dono)->patchJson("/api/vagas/{$vaga->id}", [
        'funcao_id' => $func->id,
        'data_inicio' => $vaga->data_inicio->toIso8601String(),
        'data_fim' => $vaga->data_fim->toIso8601String(),
        'valor' => 150.00,
        'posicoes' => 2,
        'observacoes' => null,
    ])->assertOk()->assertJsonPath('material', true)->assertJsonPath('candidatos_notificados', 2);

    expect($c1->fresh()->estado)->toBe(CandidaturaEstado::PendenteRevisaoAposEdicao);
    expect($c2->fresh()->estado)->toBe(CandidaturaEstado::PendenteRevisaoAposEdicao);

    // ─── 2) profissional 1 vê o diff no detalhe e MANTÉM ───
    $detalhe = $this->actingAs($prof1)->getJson("/api/vagas/{$vaga->id}/detalhe")->assertOk();
    expect($detalhe->json('revisao.diff.0.campo'))->toBe('valor');

    $this->actingAs($prof1)->postJson("/api/candidaturas/{$c1->id}/confirmar-apos-edicao")
        ->assertOk()->assertJsonPath('estado', 'pendente');

    // ─── 3) profissional 2 NÃO age. O relógio avança > 24h e o cron roda ───
    $this->travel(25)->hours();
    $this->artisan('candidaturas:auto-retirar-apos-edicao')->assertSuccessful();

    // ─── desfecho: prof1 segue pendente; prof2 saiu como retirada_por_edicao ───
    expect($c1->fresh()->estado)->toBe(CandidaturaEstado::Pendente);
    expect($c2->fresh()->estado)->toBe(CandidaturaEstado::RetiradaPorEdicao);

    $this->travelBack();
});
