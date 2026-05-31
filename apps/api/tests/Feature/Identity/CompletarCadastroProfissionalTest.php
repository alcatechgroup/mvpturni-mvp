<?php

// STORY-023 — Completar cadastro do profissional + AceiteEletronico.
// CA-1/2/3/4/5/6/7/9/10/11/12/16/17. E2E em browser fica nos specs Playwright.

use App\Models\AceiteEletronico;
use App\Models\ProfissionalProfile;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;

uses(RefreshDatabase::class);

beforeEach(function () {
    Storage::fake('local');
    seedTemplatesContratuais();
});

/** Cria os 2 templates com a v1 ativa a partir do texto-seed real (STORY-015/020). */
function seedTemplatesContratuais(): void
{
    $admin = User::factory()->admin()->create();

    foreach ([
        'pf_autonomo_eventual' => 'template-pf-autonomo-eventual-v1.md',
        'mei_pj_b2b' => 'template-mei-pj-b2b-v1.md',
    ] as $slug => $arquivo) {
        $template = Template::create(['slug' => $slug, 'nome_amigavel' => $slug]);
        TemplateVersao::create([
            'template_id' => $template->id,
            'versao' => 1,
            'conteudo' => (string) file_get_contents(database_path('seeders/contracts/'.$arquivo)),
            'criado_por_admin_id' => $admin->id,
            'ativa' => true,
        ]);
    }
}

/** Profissional liberado + welcome visto + sem cadastro completo (estado `await_cadastro`). */
function profissionalAwaitCadastro(string $tipo = 'PF', ?string $email = null): User
{
    $user = User::factory()->profissional()->liberadoWelcomeVisto()->create([
        'name' => 'Diego Silva',
        'email' => $email ?? fake()->unique()->safeEmail(),
    ]);
    ProfissionalProfile::create([
        'user_id' => $user->id,
        'tipo_pessoa' => $tipo,
        'telefone' => '11999998888',
        'cidade' => 'São Paulo',
        'bairro' => 'Centro',
    ]);

    return $user->fresh();
}

/**
 * @param  array<string,mixed>  $over
 * @return array<string,mixed>
 */
function payloadCompletar(array $over = []): array
{
    return array_merge([
        'documento' => '529.982.247-25',
        'raio_max_km' => 30,
        'preco_hora' => 45.50,
        'bio' => 'Garçom com 5 anos de experiência em eventos.',
        'chave_pix' => 'diego.pix@turni.com.br',
        // create() (não image()) — o container não tem GD; MIME explícito exercita as regras.
        'documento_comprobatorio' => UploadedFile::fake()->create('rg.jpg', 600, 'image/jpeg'),
    ], $over);
}

/** Submit multipart com Accept: application/json (erros voltam como 422 JSON, não redirect). */
function submitCompletar(User $user, array $over = []): TestResponse
{
    return test()->actingAs($user)->post(
        '/api/usuarios/me/completar-cadastro',
        payloadCompletar($over),
        ['Accept' => 'application/json'],
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// CA-1/9/12 — caminho feliz PF: aceite gerado, transição para ativo
// ─────────────────────────────────────────────────────────────────────────────

test('PF completa cadastro: gera aceite, transiciona para ativo e referencia a versão ativa', function () {
    $user = profissionalAwaitCadastro('PF');
    $versaoPf = Template::where('slug', 'pf_autonomo_eventual')->first()->versaoAtiva;

    submitCompletar($user)
        ->assertStatus(201)
        ->assertJsonPath('success', true)
        ->assertJsonPath('status', 'ativo')
        ->assertJsonPath('cadastro_completo', true);

    $user->refresh();
    expect($user->status)->toBe('ativo');
    expect($user->cadastro_completed_at)->not->toBeNull();
    expect($user->funnelState())->toBe('active');

    $aceite = AceiteEletronico::where('user_id', $user->id)->firstOrFail();
    expect($aceite->template_versao_id)->toBe($versaoPf->id);
    expect($aceite->conteudo_renderizado)
        ->toContain('529.982.247-25')
        ->toContain('Diego Silva')
        ->not->toContain('Seção 2 — Termos do turno');
    expect($aceite->dados_renderizados)->toHaveKey('profissional.documento');
    expect($aceite->ip)->not->toBeNull();
    expect($aceite->fingerprint)->not->toBeEmpty();
});

test('MEI completa cadastro com CNPJ e referencia o template mei_pj_b2b', function () {
    $user = profissionalAwaitCadastro('MEI');
    $versaoMei = Template::where('slug', 'mei_pj_b2b')->first()->versaoAtiva;

    submitCompletar($user, ['documento' => '11.222.333/0001-81'])->assertStatus(201);

    $aceite = AceiteEletronico::where('user_id', $user->id)->firstOrFail();
    expect($aceite->template_versao_id)->toBe($versaoMei->id);
    expect($aceite->conteudo_renderizado)->toContain('11.222.333/0001-81');
    expect($user->fresh()->profissionalProfile->documento_tipo)->toBe('CNPJ');
});

// ─────────────────────────────────────────────────────────────────────────────
// CA-6 — criptografia em repouso + documento_hash
// ─────────────────────────────────────────────────────────────────────────────

test('documento e chave Pix ficam criptografados em repouso (query direta != texto claro)', function () {
    $user = profissionalAwaitCadastro('PF');

    submitCompletar($user)->assertStatus(201);

    $raw = DB::table('profissional_profiles')->where('user_id', $user->id)
        ->first(['documento_encrypted', 'chave_pix_encrypted', 'documento_hash']);

    expect($raw->documento_encrypted)->not->toContain('52998224725');
    expect($raw->chave_pix_encrypted)->not->toContain('diego.pix@turni.com.br');
    expect($raw->documento_hash)->not->toBeEmpty();

    $profile = $user->fresh()->profissionalProfile;
    expect($profile->documento_encrypted)->toBe('52998224725');
    expect($profile->chave_pix_encrypted)->toBe('diego.pix@turni.com.br');
});

// ─────────────────────────────────────────────────────────────────────────────
// CA-3 — unicidade do documento (erro genérico anti-enumeração)
// ─────────────────────────────────────────────────────────────────────────────

test('documento já cadastrado por outro profissional bloqueia com erro genérico', function () {
    $primeiro = profissionalAwaitCadastro('PF');
    submitCompletar($primeiro)->assertStatus(201);

    $segundo = profissionalAwaitCadastro('PF');

    submitCompletar($segundo)
        ->assertStatus(422)
        ->assertJsonPath('code', 'documento_duplicado');

    expect($segundo->fresh()->funnelState())->toBe('await_cadastro');
});

// ─────────────────────────────────────────────────────────────────────────────
// CA-2/3/4/5 — validação de entrada
// ─────────────────────────────────────────────────────────────────────────────

test('CPF inválido é rejeitado na validação', function () {
    submitCompletar(profissionalAwaitCadastro('PF'), ['documento' => '529.982.247-24'])
        ->assertStatus(422)->assertJsonValidationErrors('documento');
});

test('chave Pix inválida é rejeitada na validação', function () {
    submitCompletar(profissionalAwaitCadastro('PF'), ['chave_pix' => 'nao-eh-chave'])
        ->assertStatus(422)->assertJsonValidationErrors('chave_pix');
});

test('documento comprobatório é obrigatório no submit final', function () {
    submitCompletar(profissionalAwaitCadastro('PF'), ['documento_comprobatorio' => null])
        ->assertStatus(422)->assertJsonValidationErrors('documento_comprobatorio');
});

test('arquivo de documento acima de 10 MB é rejeitado', function () {
    $grande = UploadedFile::fake()->create('doc.pdf', 11 * 1024, 'application/pdf');
    submitCompletar(profissionalAwaitCadastro('PF'), ['documento_comprobatorio' => $grande])
        ->assertStatus(422)->assertJsonValidationErrors('documento_comprobatorio');
});

test('bio acima de 500 caracteres é rejeitada', function () {
    submitCompletar(profissionalAwaitCadastro('PF'), ['bio' => str_repeat('a', 501)])
        ->assertStatus(422)->assertJsonValidationErrors('bio');
});

// ─────────────────────────────────────────────────────────────────────────────
// CA-10 — transação atômica: falha pós-escrita do perfil reverte tudo
// ─────────────────────────────────────────────────────────────────────────────

test('falha ao criar o aceite reverte o perfil e o status (nada persiste)', function () {
    $user = profissionalAwaitCadastro('PF');

    // Força falha DEPOIS da escrita do perfil e ANTES do commit.
    AceiteEletronico::creating(function () {
        throw new RuntimeException('falha simulada no meio da transação');
    });

    submitCompletar($user)->assertStatus(500);

    $user->refresh();
    expect($user->status)->toBe('liberado');
    expect($user->cadastro_completed_at)->toBeNull();
    expect($user->profissionalProfile->documento_encrypted)->toBeNull();
    expect(AceiteEletronico::where('user_id', $user->id)->exists())->toBeFalse();
    Storage::assertDirectoryEmpty('profissionais/documentos');
});

// ─────────────────────────────────────────────────────────────────────────────
// CA-11 — imutabilidade do aceite (trigger no banco)
// ─────────────────────────────────────────────────────────────────────────────

test('UPDATE e DELETE em aceites_eletronicos falham (imutável)', function () {
    $user = profissionalAwaitCadastro('PF');
    submitCompletar($user)->assertStatus(201);
    $aceite = AceiteEletronico::where('user_id', $user->id)->firstOrFail();

    // DB::transaction cria um SAVEPOINT: ao falhar o trigger, o rollback é até o savepoint
    // e NÃO envenena a transação externa do RefreshDatabase.
    expect(fn () => DB::transaction(fn () => DB::table('aceites_eletronicos')->where('id', $aceite->id)->update(['fingerprint' => 'x'])))
        ->toThrow(QueryException::class);
    expect(fn () => DB::transaction(fn () => DB::table('aceites_eletronicos')->where('id', $aceite->id)->delete()))
        ->toThrow(QueryException::class);

    expect(AceiteEletronico::find($aceite->id))->not->toBeNull();
});

// ─────────────────────────────────────────────────────────────────────────────
// CA-16 — ativar nova versão NÃO afeta aceites já firmados
// ─────────────────────────────────────────────────────────────────────────────

test('aceite firmado continua referenciando a versão original após nova versão ativada', function () {
    $user = profissionalAwaitCadastro('PF');
    submitCompletar($user)->assertStatus(201);

    $aceite = AceiteEletronico::where('user_id', $user->id)->firstOrFail();
    $conteudoOriginal = $aceite->conteudo_renderizado;
    $versaoOriginalId = $aceite->template_versao_id;

    // Admin ativa uma v2 do template PF (transação ADR-010 §Decisão 5).
    $template = Template::where('slug', 'pf_autonomo_eventual')->first();
    DB::transaction(function () use ($template) {
        TemplateVersao::where('template_id', $template->id)->where('ativa', true)->update(['ativa' => false]);
        TemplateVersao::create([
            'template_id' => $template->id,
            'versao' => 2,
            'conteudo' => "# Contrato v2\n## Seção 1 — Termos gerais\nNovo texto {{profissional.nome}}\n## Assinatura eletrônica\n{{aceite.timestamp}} {{aceite.ip}} {{aceite.fingerprint}}",
            'criado_por_admin_id' => User::where('role', 'admin')->first()->id,
            'ativa' => true,
        ]);
    });

    $aceite->refresh();
    expect($aceite->template_versao_id)->toBe($versaoOriginalId);
    expect($aceite->conteudo_renderizado)->toBe($conteudoOriginal);
});

// ─────────────────────────────────────────────────────────────────────────────
// CA-7 — preview renderiza sem persistir
// ─────────────────────────────────────────────────────────────────────────────

test('preview renderiza o contrato com os dados do usuário e não persiste nada', function () {
    $user = profissionalAwaitCadastro('PF');

    $resp = $this->actingAs($user)->postJson('/api/usuarios/me/completar-cadastro/preview', [
        'documento' => '529.982.247-25',
        'raio_max_km' => 30,
        'preco_hora' => 45.50,
        'chave_pix' => 'diego.pix@turni.com.br',
    ]);

    $resp->assertStatus(200)->assertJsonPath('tipo_pessoa', 'PF');
    expect($resp->json('conteudo_renderizado'))
        ->toContain('529.982.247-25')
        ->toContain('Diego Silva');

    expect(AceiteEletronico::where('user_id', $user->id)->exists())->toBeFalse();
    expect($user->fresh()->funnelState())->toBe('await_cadastro');
});

// ─────────────────────────────────────────────────────────────────────────────
// CA-17 — log estruturado user.cadastro_completed sem PII clara
// ─────────────────────────────────────────────────────────────────────────────

test('completar emite log user.cadastro_completed sem PII clara', function () {
    $user = profissionalAwaitCadastro('PF');
    Log::spy();

    submitCompletar($user)->assertStatus(201);

    Log::shouldHaveReceived('info')
        ->withArgs(function ($message, $context) use ($user) {
            return $message === 'user.cadastro_completed'
                && $context['user_id'] === $user->id
                && $context['role'] === 'profissional'
                && $context['tipo_pessoa'] === 'PF'
                && isset($context['template_versao_id'])
                && ! in_array($user->name, $context, true)
                && ! in_array($user->email, $context, true)
                && ! in_array('52998224725', $context, true);
        })->once();
});

// ─────────────────────────────────────────────────────────────────────────────
// Proteção de acesso + funil
// ─────────────────────────────────────────────────────────────────────────────

test('não-autenticado não completa cadastro', function () {
    $this->postJson('/api/usuarios/me/completar-cadastro', [])->assertStatus(401);
});

test('admin não acessa o endpoint do WebApp', function () {
    submitCompletar(User::factory()->admin()->create())->assertStatus(403);
});

test('profissional já ativo não pode completar de novo (funil inválido)', function () {
    $user = profissionalAwaitCadastro('PF');
    submitCompletar($user)->assertStatus(201);

    submitCompletar($user->fresh(), ['documento' => '111.444.777-35'])
        ->assertStatus(422)->assertJsonPath('code', 'funil_invalido');
});
