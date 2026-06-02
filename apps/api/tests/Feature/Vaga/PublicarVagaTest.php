<?php

// STORY-046 — POST /api/vagas: contratante publica vaga (form do WebApp + gate PDR-005).
// Cobre CA-1 (RBAC 403 profissional), CA-2 (campos obrigatórios + espelho server),
// CA-3 (data_fim > data_inicio), CA-6 (201 + estado aberta + versão 1 + audit vaga.criada),
// CA-10 (telemetria vaga.publicada). Localização derivada do contratante (ADR-013).

use App\Models\AuditLog;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Log;

uses(RefreshDatabase::class);

function funcaoSeed(): Funcao
{
    return Funcao::firstOrCreate(['slug' => 'bartender'], ['nome' => 'Bartender', 'ativo' => true]);
}

function contratanteAtivoComPerfil(): User
{
    $user = User::factory()->contratante()->ativo()->create();
    ContratanteProfile::create([
        'user_id' => $user->id,
        'nome_estabelecimento' => 'Bar do Zé',
        'tipo_operacao' => 'bar',
        'cidade' => 'São Paulo',
        'uf' => 'SP',
    ]);

    return $user;
}

/** @return array<string,mixed> */
function payloadVaga(array $over = []): array
{
    return array_merge([
        'funcao_id' => funcaoSeed()->id,
        'data_inicio' => now()->addDays(3)->setTime(18, 0)->toIso8601String(),
        'data_fim' => now()->addDays(3)->setTime(23, 0)->toIso8601String(),
        'valor' => 150.00,
        'posicoes' => 2,
        'observacoes' => 'Camisa preta.',
    ], $over);
}

// ───────────────────────── CA-6 — caminho feliz ─────────────────────────

test('contratante ativo publica vaga válida → 201, estado aberta, persistida (CA-6)', function () {
    $contratante = contratanteAtivoComPerfil();

    $res = $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga());

    $res->assertStatus(201)
        ->assertJsonPath('estado', 'aberta')
        ->assertJsonStructure(['id', 'estado', 'funcao_id', 'data_inicio', 'data_fim', 'valor', 'posicoes']);

    $vaga = Vaga::firstWhere('contratante_id', $contratante->id);
    expect($vaga)->not->toBeNull()
        ->and($vaga->estado->value)->toBe('aberta')
        ->and($vaga->posicoes)->toBe(2)
        ->and($vaga->posicoes_preenchidas)->toBe(0)
        ->and($vaga->versao_atual)->toBe(1)
        ->and($vaga->publicada_em)->not->toBeNull();
});

test('publicar grava a versão 1 (snapshot inicial — ADR-013 Decisão 1)', function () {
    $contratante = contratanteAtivoComPerfil();

    $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga())->assertStatus(201);

    $vaga = Vaga::firstWhere('contratante_id', $contratante->id);
    $versao = VagaVersao::where('vaga_id', $vaga->id)->where('versao', 1)->first();

    expect($versao)->not->toBeNull()
        ->and($versao->snapshot)->toHaveKeys(['funcao_id', 'data_inicio', 'data_fim', 'valor', 'posicoes'])
        ->and($versao->snapshot['posicoes'])->toBe(2);
});

test('publicar registra audit_logs vaga.criada com ator e payload (CA-6)', function () {
    $contratante = contratanteAtivoComPerfil();
    $funcao = funcaoSeed();

    $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga(['funcao_id' => $funcao->id]))->assertStatus(201);

    $vaga = Vaga::firstWhere('contratante_id', $contratante->id);
    $log = AuditLog::where('action', 'vaga.criada')->where('target_id', $vaga->id)->first();

    expect($log)->not->toBeNull()
        ->and($log->target_type)->toBe('Vaga')
        ->and($log->actor_id)->toBe($contratante->id)
        ->and($log->payload)->toEqual(['funcao_id' => $funcao->id, 'posicoes' => 2]);
});

test('publicar emite telemetria estruturada vaga.publicada (CA-10)', function () {
    Log::spy();
    $contratante = contratanteAtivoComPerfil();
    $funcao = funcaoSeed();

    $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga(['funcao_id' => $funcao->id]))->assertStatus(201);

    Log::shouldHaveReceived('info')->withArgs(function ($message, $context = []) use ($contratante, $funcao) {
        return $message === 'vaga.publicada'
            && ($context['event'] ?? null) === 'vaga.publicada'
            && ($context['contratante_id'] ?? null) === $contratante->id
            && ($context['funcao'] ?? null) === $funcao->id
            && ($context['posicoes'] ?? null) === 2
            && array_key_exists('vaga_id', $context)
            && array_key_exists('valor', $context);
    })->once();
});

test('vaga herda cidade/uf do perfil do contratante (ADR-013 — sem coletar endereço)', function () {
    $contratante = contratanteAtivoComPerfil();

    $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga())->assertStatus(201);

    $vaga = Vaga::firstWhere('contratante_id', $contratante->id);
    expect($vaga->cidade)->toBe('São Paulo')->and($vaga->uf)->toBe('SP');
});

test('observações é opcional — publica sem observações (borda)', function () {
    $contratante = contratanteAtivoComPerfil();

    $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga(['observacoes' => null]))
        ->assertStatus(201);
});

// ───────────────────────── CA-1 — RBAC ─────────────────────────

test('profissional recebe 403 ao tentar publicar vaga (CA-1)', function () {
    $prof = User::factory()->profissional()->ativo()->create();

    $this->actingAs($prof)->postJson('/api/vagas', payloadVaga())->assertStatus(403);
    expect(Vaga::count())->toBe(0);
});

test('não autenticado recebe 401 (exceção)', function () {
    $this->postJson('/api/vagas', payloadVaga())->assertStatus(401);
});

// ───────────────────────── CA-2 / CA-3 — validação (espelho server) ─────────────────────────

test('campo obrigatório ausente → 422 no campo certo (CA-2)', function (string $campo) {
    $contratante = contratanteAtivoComPerfil();

    $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga([$campo => null]))
        ->assertStatus(422)->assertJsonValidationErrors($campo);
})->with(['funcao_id', 'data_inicio', 'data_fim', 'valor', 'posicoes']);

test('data_fim ≤ data_inicio → 422 (CA-3)', function () {
    $contratante = contratanteAtivoComPerfil();
    $inicio = now()->addDays(3)->setTime(20, 0);

    $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga([
        'data_inicio' => $inicio->toIso8601String(),
        'data_fim' => $inicio->copy()->subHour()->toIso8601String(),
    ]))->assertStatus(422)->assertJsonValidationErrors('data_fim');
});

test('posicoes < 1 → 422 (CA-2)', function () {
    $contratante = contratanteAtivoComPerfil();

    $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga(['posicoes' => 0]))
        ->assertStatus(422)->assertJsonValidationErrors('posicoes');
});

test('valor ≤ 0 → 422 (CA-2)', function () {
    $contratante = contratanteAtivoComPerfil();

    $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga(['valor' => 0]))
        ->assertStatus(422)->assertJsonValidationErrors('valor');
});

test('funcao_id fora da lista canônica → 422 (CA-2/CA-4)', function () {
    $contratante = contratanteAtivoComPerfil();

    $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga(['funcao_id' => 999999]))
        ->assertStatus(422)->assertJsonValidationErrors('funcao_id');
});

test('funcao inativa não é aceita → 422 (CA-4)', function () {
    $contratante = contratanteAtivoComPerfil();
    $inativa = Funcao::create(['slug' => 'descontinuada', 'nome' => 'Antiga', 'ativo' => false]);

    $this->actingAs($contratante)->postJson('/api/vagas', payloadVaga(['funcao_id' => $inativa->id]))
        ->assertStatus(422)->assertJsonValidationErrors('funcao_id');
});
