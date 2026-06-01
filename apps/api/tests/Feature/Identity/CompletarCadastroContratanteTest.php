<?php

// STORY-024 — Completar cadastro do contratante + AceiteEletronico (adesão à plataforma).
// CA-1/2/3/4/5/6/9/10/12 cobertos aqui (E2E em browser real cobre CA-15 na pipeline).
// O texto-seed real de `termos_plataforma_contratante` é authoring do PO (IDR-023); estes
// testes usam um template-fixture com os placeholders do contrato definido pelo serviço.

use App\Models\AceiteEletronico;
use App\Models\ContratanteProfile;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Database\Seeders\TemplatesContratuaisSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;

uses(RefreshDatabase::class);

const CNPJ_CONTRATANTE_OK = '11222333000181';

beforeEach(function () {
    Storage::fake('local');
    // Usa o texto-seed REAL de termos_plataforma_contratante (IDR-023), não um fixture.
    User::factory()->admin()->create();
    test()->seed(TemplatesContratuaisSeeder::class);
});

function contratanteEmCadastro(string $nomeEstabelecimento = 'Bar do Zé'): User
{
    $user = User::factory()->contratante()->liberadoWelcomeVisto()->create(['name' => 'Zé Responsável']);

    ContratanteProfile::create([
        'user_id' => $user->id,
        'nome_estabelecimento' => $nomeEstabelecimento,
        'tipo_operacao' => 'bar',
        'telefone' => '11999990000',
        'cidade' => 'São Paulo',
    ]);

    return $user;
}

/** @return array<string,mixed> */
function payloadContratante(array $over = []): array
{
    return array_merge([
        'cnpj' => CNPJ_CONTRATANTE_OK,
        'cep' => '01001-000',
        'logradouro' => 'Praça da Sé',
        'numero' => '100',
        'bairro' => 'Sé',
        'cidade' => 'São Paulo',
        'uf' => 'SP',
        'complemento' => 'Sala 2',
        'apelido_estabelecimento' => 'Zé',
        'segmento' => 'Bar e petiscaria',
        'ano_fundacao' => 2015,
        'qtd_funcionarios' => '11-50',
        'turnos_operacao' => 'Noite',
        'cultura_valores' => 'Atendimento caloroso',
        'site' => 'https://bardoze.example',
        'redes_sociais' => ['instagram' => 'https://instagram.com/bardoze'],
        'contatos_adicionais' => [
            ['nome' => 'Ana', 'funcao' => 'Gerente', 'telefone' => '11988887777'],
        ],
    ], $over);
}

// ── CA-1 — contexto ──────────────────────────────────────────────────────────

test('CA-1: contexto retorna nome do responsável e documento_tipo CNPJ', function () {
    $user = contratanteEmCadastro();

    $this->actingAs($user)->getJson('/api/cadastro/contratante/completar/contexto')
        ->assertStatus(200)
        ->assertJsonPath('nome', 'Zé Responsável')
        ->assertJsonPath('documento_tipo', 'CNPJ')
        ->assertJsonPath('nome_estabelecimento', 'Bar do Zé');
});

// ── CA-9/12 — happy path ─────────────────────────────────────────────────────

test('CA-9/12: contratante conclui cadastro, gera aceite, vira ativo com plano Member Start', function () {
    $user = contratanteEmCadastro();

    $res = $this->actingAs($user)->post('/api/cadastro/contratante/completar', payloadContratante());

    $res->assertStatus(201)->assertJsonPath('success', true);

    $user->refresh();
    expect($user->status)->toBe('ativo');
    expect($user->cadastro_completed_at)->not->toBeNull();
    expect($user->funnelState())->toBe('active');

    $aceite = AceiteEletronico::where('user_id', $user->id)->firstOrFail();
    $versaoAtiva = Template::where('slug', 'termos_plataforma_contratante')->first()->versaoAtiva;
    expect($aceite->template_versao_id)->toBe($versaoAtiva->id);
    expect($aceite->conteudo_renderizado)
        ->toContain('Bar do Zé')
        ->toContain('11.222.333/0001-81')
        ->toContain('15%') // taxa Turni (cláusula 4 do template real)
        ->not->toContain('Dúvidas registradas') // ## Notas do PO omitida (IDR-022)
        ->not->toContain('Histórico de validação')
        ->not->toContain('{{');
    expect($aceite->dados_renderizados)->toHaveKeys(['contratante.razao_social', 'contratante.cnpj', 'aceite.ip']);

    $profile = $user->contratanteProfile->fresh();
    expect($profile->plano)->toBe('member_start');
    expect($profile->cnpj_encrypted)->toBe(CNPJ_CONTRATANTE_OK); // cast decripta
    expect($profile->uf)->toBe('SP');
    expect($profile->contatos_adicionais)->toHaveCount(1);
});

test('CA-7: preview renderiza termos com CNPJ, razão e marcador de assinatura pendente', function () {
    $user = contratanteEmCadastro();

    $res = $this->actingAs($user)->postJson('/api/cadastro/contratante/completar/preview', ['cnpj' => CNPJ_CONTRATANTE_OK]);

    $res->assertStatus(200);
    expect($res->json('conteudo'))
        ->toContain('11.222.333/0001-81')
        ->toContain('Bar do Zé')
        ->toContain('15%')
        ->toContain('preenchido no momento do aceite')
        ->not->toContain('Dúvidas registradas')
        ->not->toContain('{{');
});

// ── CA-3 — CNPJ ──────────────────────────────────────────────────────────────

test('CA-3: CNPJ inválido (dígitos verificadores) é rejeitado', function () {
    $user = contratanteEmCadastro();

    $this->actingAs($user)->postJson('/api/cadastro/contratante/completar', payloadContratante(['cnpj' => '11222333000100']))
        ->assertStatus(422)->assertJsonValidationErrors('cnpj');

    expect($user->fresh()->status)->toBe('liberado');
});

test('CA-3: CNPJ duplicado bloqueia com erro genérico e nada persiste', function () {
    $primeiro = contratanteEmCadastro('Bar do Zé');
    $this->actingAs($primeiro)->post('/api/cadastro/contratante/completar', payloadContratante())->assertStatus(201);

    $segundo = contratanteEmCadastro('Outro Bar');
    $res = $this->actingAs($segundo)->post('/api/cadastro/contratante/completar', payloadContratante());

    $res->assertStatus(422)->assertJsonValidationErrors('cnpj');
    expect($segundo->fresh()->status)->toBe('liberado');
    expect(AceiteEletronico::where('user_id', $segundo->id)->exists())->toBeFalse();
});

// ── CA-2 — validação dos campos ──────────────────────────────────────────────

test('CA-2: campo de endereço obrigatório ausente é rejeitado', function () {
    $user = contratanteEmCadastro();

    $this->actingAs($user)->postJson('/api/cadastro/contratante/completar', payloadContratante(['logradouro' => '']))
        ->assertStatus(422)->assertJsonValidationErrors('logradouro');
});

test('CA-2: ano de fundação fora de faixa é rejeitado', function () {
    $user = contratanteEmCadastro();

    $this->actingAs($user)->postJson('/api/cadastro/contratante/completar', payloadContratante(['ano_fundacao' => 1700]))
        ->assertStatus(422)->assertJsonValidationErrors('ano_fundacao');
    $this->actingAs($user)->postJson('/api/cadastro/contratante/completar', payloadContratante(['ano_fundacao' => 3000]))
        ->assertStatus(422)->assertJsonValidationErrors('ano_fundacao');
});

test('CA-2: faixa de funcionários fora do enum é rejeitada', function () {
    $user = contratanteEmCadastro();

    $this->actingAs($user)->postJson('/api/cadastro/contratante/completar', payloadContratante(['qtd_funcionarios' => '5000']))
        ->assertStatus(422)->assertJsonValidationErrors('qtd_funcionarios');
});

test('CA-2: contato adicional sem nome é rejeitado (borda da lista dinâmica)', function () {
    $user = contratanteEmCadastro();

    $this->actingAs($user)->postJson('/api/cadastro/contratante/completar', payloadContratante([
        'contatos_adicionais' => [['nome' => '', 'funcao' => 'Chef', 'telefone' => '1199']],
    ]))->assertStatus(422)->assertJsonValidationErrors('contatos_adicionais.0.nome');
});

test('CA-2: sem contatos adicionais é aceito (lista vazia — borda)', function () {
    $user = contratanteEmCadastro();

    $this->actingAs($user)->post('/api/cadastro/contratante/completar', payloadContratante(['contatos_adicionais' => []]))
        ->assertStatus(201);
});

// ── CA-5 — upload de logo ────────────────────────────────────────────────────

test('CA-5: logo com MIME não permitido é rejeitada', function () {
    $user = contratanteEmCadastro();

    $this->actingAs($user)->post('/api/cadastro/contratante/completar', payloadContratante([
        'logo' => UploadedFile::fake()->create('logo.exe', 100, 'application/x-msdownload'),
    ]))->assertStatus(422)->assertJsonValidationErrors('logo');
});

test('CA-5: logo acima de 5 MB é rejeitada', function () {
    $user = contratanteEmCadastro();

    $this->actingAs($user)->post('/api/cadastro/contratante/completar', payloadContratante([
        'logo' => UploadedFile::fake()->create('logo.png', 6000, 'image/png'),
    ]))->assertStatus(422)->assertJsonValidationErrors('logo');
});

test('CA-5: logo válida é armazenada em disco privado', function () {
    $user = contratanteEmCadastro();

    $this->actingAs($user)->post('/api/cadastro/contratante/completar', payloadContratante([
        'logo' => UploadedFile::fake()->create('logo.png', 200, 'image/png'),
    ]))->assertStatus(201);

    $path = $user->contratanteProfile->fresh()->logo_path;
    expect($path)->not->toBeNull();
    Storage::assertExists($path);
});

// ── CA-4 — busca de CEP (endpoint) ───────────────────────────────────────────

test('CA-4: endpoint de CEP retorna endereço (caminho feliz)', function () {
    Http::fake(['viacep.com.br/*' => Http::response([
        'logradouro' => 'Praça da Sé', 'bairro' => 'Sé', 'localidade' => 'São Paulo', 'uf' => 'SP',
    ], 200)]);
    $user = contratanteEmCadastro();

    $this->actingAs($user)->getJson('/api/cadastro/contratante/completar/cep/01001000')
        ->assertStatus(200)
        ->assertJsonPath('uf', 'SP')
        ->assertJsonPath('cidade', 'São Paulo');
});

test('CA-4: falha da API de CEP não bloqueia (204), submit manual segue', function () {
    Http::fake(['viacep.com.br/*' => Http::response('', 500)]);
    $user = contratanteEmCadastro();

    $this->actingAs($user)->getJson('/api/cadastro/contratante/completar/cep/01001000')->assertStatus(204);
});

// ── CA-6 — criptografia em repouso ───────────────────────────────────────────

test('CA-6: CNPJ fica cifrado no Postgres (query direta não vê texto claro)', function () {
    $user = contratanteEmCadastro();
    $this->actingAs($user)->post('/api/cadastro/contratante/completar', payloadContratante())->assertStatus(201);

    $raw = DB::table('contratante_profiles')->where('user_id', $user->id)->first();
    expect($raw->cnpj_encrypted)->not->toContain(CNPJ_CONTRATANTE_OK);
    expect($user->contratanteProfile->fresh()->cnpj_encrypted)->toBe(CNPJ_CONTRATANTE_OK);
});

// ── CA-10 — atomicidade ──────────────────────────────────────────────────────

test('CA-10: sem versão ativa do template, nada persiste (503) e estado é preservado', function () {
    $user = contratanteEmCadastro();
    TemplateVersao::query()->update(['ativa' => false]);

    $this->actingAs($user)->post('/api/cadastro/contratante/completar', payloadContratante())->assertStatus(503);

    expect($user->fresh()->status)->toBe('liberado');
    expect(AceiteEletronico::where('user_id', $user->id)->exists())->toBeFalse();
    expect($user->contratanteProfile->fresh()->cnpj_hash)->toBeNull();
});

// ── auth / funil ─────────────────────────────────────────────────────────────

test('contratante pendente não acessa completar cadastro (403)', function () {
    $user = User::factory()->contratante()->pendenteAprovacao()->create();
    ContratanteProfile::create(['user_id' => $user->id, 'nome_estabelecimento' => 'X']);

    $this->actingAs($user)->post('/api/cadastro/contratante/completar', payloadContratante())->assertStatus(403);
});

test('contratante já ativo não reabre completar cadastro (403)', function () {
    $user = contratanteEmCadastro();
    $this->actingAs($user)->post('/api/cadastro/contratante/completar', payloadContratante())->assertStatus(201);

    $this->actingAs($user->fresh())->post('/api/cadastro/contratante/completar', payloadContratante())->assertStatus(403);
});

test('não autenticado recebe 401', function () {
    $this->postJson('/api/cadastro/contratante/completar/preview', ['cnpj' => CNPJ_CONTRATANTE_OK])->assertStatus(401);
});
