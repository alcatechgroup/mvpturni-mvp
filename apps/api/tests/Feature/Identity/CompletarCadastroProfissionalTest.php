<?php

// STORY-023 — Completar cadastro do profissional + AceiteEletronico.
// CA-1/3/5/6/9/10/11/12/16 cobertos aqui (E2E em browser real cobre CA-15/16 na pipeline).

use App\Models\AceiteEletronico;
use App\Models\Funcao;
use App\Models\ProfissionalProfile;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Database\Seeders\TemplatesContratuaisSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

uses(RefreshDatabase::class);

const CPF_OK = '11144477735';
const CNPJ_OK = '11222333000181';

beforeEach(function () {
    Storage::fake('local');
    User::factory()->admin()->create();
    test()->seed(TemplatesContratuaisSeeder::class);
});

function profissionalEmCadastro(string $tipo = 'PF', string $nome = 'Maria Silva'): User
{
    $funcao = Funcao::firstOrCreate(['slug' => 'garcom'], ['nome' => 'Garçom / Garçonete', 'ativo' => true]);

    $user = User::factory()->profissional()->liberadoWelcomeVisto()->create(['name' => $nome]);

    ProfissionalProfile::create([
        'user_id' => $user->id,
        'tipo_pessoa' => $tipo,
        'telefone' => '11999990000',
        'cidade' => 'São Paulo',
        'bairro' => 'Centro',
        'funcao_id' => $funcao->id,
    ]);

    return $user;
}

/** @return array<string,mixed> */
function payloadValido(array $over = []): array
{
    return array_merge([
        'documento' => CPF_OK,
        'raio_max_km' => 20,
        'preco_hora' => 50,
        'bio' => 'Garçom experiente',
        'chave_pix' => 'maria@exemplo.com',
        'documentos_comprobatorios' => [UploadedFile::fake()->create('rg.jpg', 100, 'image/jpeg')],
    ], $over);
}

// ── CA-1/9/12 — happy path PF ────────────────────────────────────────────────

test('CA-9/12: PF conclui cadastro, gera aceite e vira ativo', function () {
    $user = profissionalEmCadastro('PF');

    $res = $this->actingAs($user)->post('/api/cadastro/profissional/completar', payloadValido());

    $res->assertStatus(201)->assertJsonPath('success', true);

    $user->refresh();
    expect($user->status)->toBe('ativo');
    expect($user->cadastro_completed_at)->not->toBeNull();
    expect($user->funnelState())->toBe('active');

    $aceite = AceiteEletronico::where('user_id', $user->id)->firstOrFail();
    $versaoAtiva = Template::where('slug', 'pf_autonomo_eventual')->first()->versaoAtiva;
    expect($aceite->template_versao_id)->toBe($versaoAtiva->id);
    expect($aceite->conteudo_renderizado)
        ->toContain('Maria Silva')
        ->toContain('111.444.777-35')
        ->not->toContain('{{');
    expect($aceite->dados_renderizados)->toHaveKeys(['profissional.nome', 'profissional.documento', 'aceite.ip']);
    expect($aceite->ip)->not->toBeNull();
    expect($aceite->fingerprint)->toBeString();

    $profile = $user->profissionalProfile->fresh();
    expect($profile->documento_tipo)->toBe('CPF');
    expect($profile->documento_encrypted)->toBe(CPF_OK); // cast decripta
    expect($profile->preco_hora)->toBe('50.00');
    expect($profile->documentos_comprobatorios)->toHaveCount(1);
});

test('CA-7: preview renderiza contrato com CPF e marcador de assinatura pendente', function () {
    $user = profissionalEmCadastro('PF');

    $res = $this->actingAs($user)->postJson('/api/cadastro/profissional/completar/preview', ['documento' => CPF_OK]);

    $res->assertStatus(200);
    expect($res->json('conteudo'))
        ->toContain('111.444.777-35')
        ->toContain('Maria Silva')
        ->toContain('preenchido no momento do aceite')
        ->not->toContain('## Seção 2')
        ->not->toContain('## Notas do PO')
        ->not->toContain('{{');
});

test('contexto retorna tipo_pessoa e documento_tipo do perfil', function () {
    $pf = profissionalEmCadastro('PF');
    $this->actingAs($pf)->getJson('/api/cadastro/profissional/completar/contexto')
        ->assertStatus(200)
        ->assertJsonPath('tipo_pessoa', 'PF')
        ->assertJsonPath('documento_tipo', 'CPF');

    $mei = profissionalEmCadastro('MEI', 'João MEI');
    $this->actingAs($mei)->getJson('/api/cadastro/profissional/completar/contexto')
        ->assertStatus(200)
        ->assertJsonPath('documento_tipo', 'CNPJ');
});

// ── CA-3 — documento por tipo + unicidade ────────────────────────────────────

test('CA-3: PF com CPF inválido é rejeitado', function () {
    $user = profissionalEmCadastro('PF');

    $this->actingAs($user)->postJson('/api/cadastro/profissional/completar', payloadValido(['documento' => '11144477700']))
        ->assertStatus(422)->assertJsonValidationErrors('documento');

    expect($user->fresh()->status)->toBe('liberado');
});

test('CA-3: MEI precisa de CNPJ — CPF é rejeitado', function () {
    $user = profissionalEmCadastro('MEI');

    $this->actingAs($user)->postJson('/api/cadastro/profissional/completar', payloadValido(['documento' => CPF_OK]))
        ->assertStatus(422)->assertJsonValidationErrors('documento');
});

test('CA-3: documento duplicado bloqueia com erro genérico e nada persiste', function () {
    $primeiro = profissionalEmCadastro('PF', 'Maria Silva');
    $this->actingAs($primeiro)->post('/api/cadastro/profissional/completar', payloadValido())->assertStatus(201);

    $segundo = profissionalEmCadastro('PF', 'João Souza');
    $res = $this->actingAs($segundo)->post('/api/cadastro/profissional/completar', payloadValido(['chave_pix' => 'joao@exemplo.com']));

    $res->assertStatus(422)->assertJsonValidationErrors('documento');
    expect($segundo->fresh()->status)->toBe('liberado');
    expect(AceiteEletronico::where('user_id', $segundo->id)->exists())->toBeFalse();
});

// ── CA-4 — chave Pix ─────────────────────────────────────────────────────────

test('CA-4: chave Pix inválida é rejeitada', function () {
    $user = profissionalEmCadastro('PF');

    $this->actingAs($user)->postJson('/api/cadastro/profissional/completar', payloadValido(['chave_pix' => 'chave qualquer']))
        ->assertStatus(422)->assertJsonValidationErrors('chave_pix');
});

// ── CA-5 — upload de documentos ──────────────────────────────────────────────

test('CA-5: rejeita arquivo com MIME não permitido', function () {
    $user = profissionalEmCadastro('PF');

    $this->actingAs($user)->post('/api/cadastro/profissional/completar', payloadValido([
        'documentos_comprobatorios' => [UploadedFile::fake()->create('virus.exe', 100, 'application/x-msdownload')],
    ]))->assertStatus(422)->assertJsonValidationErrors('documentos_comprobatorios.0');
});

test('CA-5: rejeita arquivo acima de 10 MB', function () {
    $user = profissionalEmCadastro('PF');

    $this->actingAs($user)->post('/api/cadastro/profissional/completar', payloadValido([
        'documentos_comprobatorios' => [UploadedFile::fake()->create('grande.pdf', 11000, 'application/pdf')],
    ]))->assertStatus(422)->assertJsonValidationErrors('documentos_comprobatorios.0');
});

// ── CA-6 — criptografia em repouso ───────────────────────────────────────────

test('CA-6: documento e chave Pix ficam cifrados no Postgres (query direta não vê texto claro)', function () {
    $user = profissionalEmCadastro('PF');
    $this->actingAs($user)->post('/api/cadastro/profissional/completar', payloadValido())->assertStatus(201);

    $raw = DB::table('profissional_profiles')->where('user_id', $user->id)->first();
    expect($raw->documento_encrypted)->not->toContain(CPF_OK);
    expect($raw->chave_pix_encrypted)->not->toContain('maria@exemplo.com');

    // Mas o model decripta transparentemente.
    expect($user->profissionalProfile->fresh()->documento_encrypted)->toBe(CPF_OK);
});

// ── CA-11 — imutabilidade do aceite (trigger) ────────────────────────────────

test('CA-11: aceite é imutável — UPDATE/DELETE direto lançam exceção do banco', function () {
    $user = profissionalEmCadastro('PF');
    $this->actingAs($user)->post('/api/cadastro/profissional/completar', payloadValido())->assertStatus(201);
    $aceite = AceiteEletronico::where('user_id', $user->id)->firstOrFail();

    expect(fn () => DB::statement('UPDATE aceites_eletronicos SET ip = ? WHERE id = ?', ['0.0.0.0', $aceite->id]))
        ->toThrow(Exception::class);
    expect(fn () => DB::statement('DELETE FROM aceites_eletronicos WHERE id = ?', [$aceite->id]))
        ->toThrow(Exception::class);
});

// ── CA-16 — imutabilidade após nova versão do template ───────────────────────

test('CA-16: aceite continua na versão original após admin ativar nova versão', function () {
    $user = profissionalEmCadastro('PF');
    $this->actingAs($user)->post('/api/cadastro/profissional/completar', payloadValido())->assertStatus(201);

    $aceite = AceiteEletronico::where('user_id', $user->id)->firstOrFail();
    $versaoOriginalId = $aceite->template_versao_id;
    $conteudoOriginal = $aceite->conteudo_renderizado;

    // Admin cria e ativa uma v2 do mesmo template (fluxo de ativação ADR-010 Decisão 5).
    $template = Template::where('slug', 'pf_autonomo_eventual')->first();
    $admin = User::where('role', 'admin')->first();
    DB::transaction(function () use ($template, $admin) {
        TemplateVersao::where('template_id', $template->id)->where('ativa', true)->update(['ativa' => false]);
        TemplateVersao::create([
            'template_id' => $template->id,
            'versao' => 2,
            'conteudo' => "# Contrato v2\n\n## Seção 1 — Termos gerais\nTexto NOVO {{profissional.nome}}.\n\n## Assinatura eletrônica\n{{aceite.timestamp}} {{aceite.ip}} {{aceite.fingerprint}}\n",
            'criado_por_admin_id' => $admin->id,
            'ativa' => true,
        ]);
    });

    $aceite->refresh();
    expect($aceite->template_versao_id)->toBe($versaoOriginalId);
    expect($aceite->conteudo_renderizado)->toBe($conteudoOriginal);
    expect($aceite->templateVersao->versao)->toBe(1);
    expect($aceite->conteudo_renderizado)->not->toContain('Texto NOVO');
});

// ── CA-10 — atomicidade: template indisponível → nada persiste ───────────────

test('CA-10: sem versão ativa do template, nada persiste e arquivos são limpos', function () {
    $user = profissionalEmCadastro('PF');
    TemplateVersao::query()->update(['ativa' => false]); // simula estado inválido

    $res = $this->actingAs($user)->post('/api/cadastro/profissional/completar', payloadValido());

    $res->assertStatus(503);
    expect($user->fresh()->status)->toBe('liberado');
    expect(AceiteEletronico::where('user_id', $user->id)->exists())->toBeFalse();
    expect($user->profissionalProfile->fresh()->documento_hash)->toBeNull();
});

// ── auth / funil ─────────────────────────────────────────────────────────────

test('usuário pendente não acessa completar cadastro (403)', function () {
    $user = User::factory()->profissional()->pendenteAprovacao()->create();
    ProfissionalProfile::create(['user_id' => $user->id, 'tipo_pessoa' => 'PF']);

    $this->actingAs($user)->post('/api/cadastro/profissional/completar', payloadValido())->assertStatus(403);
});

test('usuário já ativo não reabre completar cadastro (403)', function () {
    $user = profissionalEmCadastro('PF');
    $this->actingAs($user)->post('/api/cadastro/profissional/completar', payloadValido())->assertStatus(201);

    $this->actingAs($user->fresh())->post('/api/cadastro/profissional/completar', payloadValido())->assertStatus(403);
});

test('não autenticado recebe 401', function () {
    $this->postJson('/api/cadastro/profissional/completar/preview', ['documento' => CPF_OK])->assertStatus(401);
});
