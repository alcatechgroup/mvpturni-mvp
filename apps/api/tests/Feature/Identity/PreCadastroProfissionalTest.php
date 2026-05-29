<?php

// STORY-017 — CA-3, CA-4, CA-5, CA-6, CA-9, CA-12, CA-14 — Pré-cadastro de profissional.

use App\Models\Funcao;
use App\Models\User;
use Illuminate\Foundation\Http\Middleware\PreventRequestForgery;
use Illuminate\Foundation\Http\Middleware\VerifyCsrfToken;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful;

uses(RefreshDatabase::class);

beforeEach(function () {
    Storage::fake('local');
    $this->funcao = Funcao::create(['slug' => 'garcom', 'nome' => 'Garçom / Garçonete', 'ativo' => true]);
});

// CSRF/stateful são validados no E2E em browser real (CA-9); aqui focamos a lógica.
function cadastroPost(array $overrides = []): TestResponse
{
    $payload = array_merge([
        'name' => 'Diego Profissional',
        'email' => 'diego@example.com',
        'telefone' => '(11) 91234-5678',
        'cidade' => 'São Paulo',
        'bairro' => 'Pinheiros',
        'funcao_id' => test()->funcao->id,
        'tipo_pessoa' => 'PF',
        'password' => 'SenhaForte10',
        'password_confirmation' => 'SenhaForte10',
        'termos_aceitos' => true,
        // create() em vez de image() — o container não tem a extensão GD; o MIME
        // explícito exercita as regras image/mimes/max sem gerar pixels.
        'foto' => UploadedFile::fake()->create('foto.jpg', 600, 'image/jpeg'),
    ], $overrides);

    return test()
        ->withoutMiddleware([
            EnsureFrontendRequestsAreStateful::class,
            VerifyCsrfToken::class,
            PreventRequestForgery::class,
        ])
        ->withSession([])
        ->post('/api/cadastro/profissional', $payload);
}

// ──────────────────────────────────────────────────────────────
// CA-3 / CA-9: criação bem-sucedida persiste corretamente nos 3 tipos
// ──────────────────────────────────────────────────────────────

test('cria profissional pendente_aprovacao com perfil para cada tipo_pessoa', function (string $tipo) {
    $response = cadastroPost([
        'email' => strtolower($tipo).'@example.com',
        'tipo_pessoa' => $tipo,
    ]);

    $response->assertCreated()
        ->assertJson(['success' => true])
        ->assertJsonStructure(['success', 'message']);

    $user = User::where('email', strtolower($tipo).'@example.com')->first();
    expect($user)->not->toBeNull();
    expect($user->role)->toBe('profissional');
    expect($user->status)->toBe('pendente_aprovacao');
    expect($user->welcome_seen_at)->toBeNull();
    expect($user->cadastro_completed_at)->toBeNull();

    $profile = $user->profissionalProfile;
    expect($profile)->not->toBeNull();
    expect($profile->tipo_pessoa)->toBe($tipo);
    expect($profile->cidade)->toBe('São Paulo');
    expect($profile->bairro)->toBe('Pinheiros');
    expect($profile->funcao_id)->toBe($this->funcao->id);
    expect($profile->termos_aceitos_at)->not->toBeNull();
    expect($profile->foto_path)->not->toBeNull();
    Storage::disk('local')->assertExists($profile->foto_path);
})->with(['PF', 'MEI', 'PJ']);

// CA-3: senha com hash Argon2id; nunca volta no response
test('senha é hasheada com argon2id e nunca aparece no response', function () {
    $response = cadastroPost(['email' => 'hash@example.com']);
    $response->assertCreated();

    $user = User::where('email', 'hash@example.com')->first();
    expect($user->password)->not->toBe('SenhaForte10');
    expect($user->password)->toStartWith('$argon2id$');
    expect(password_verify('SenhaForte10', $user->password))->toBeTrue();

    // Nem o hash nem o plaintext vazam no corpo da resposta.
    $body = $response->getContent();
    expect($body)->not->toContain('SenhaForte10');
    expect($body)->not->toContain($user->password);
});

// CA-3 / CA-12: não loga senha; loga evento estruturado com e-mail mascarado
test('emite log estruturado user.preregistered com e-mail mascarado e sem senha', function () {
    Log::spy();

    cadastroPost(['email' => 'diego.silva@gmail.com', 'tipo_pessoa' => 'MEI'])->assertCreated();

    Log::shouldHaveReceived('info')
        ->withArgs(function ($message, $context = []) {
            return $message === 'user.preregistered'
                && ($context['event'] ?? null) === 'user.preregistered'
                && ($context['tipo_pessoa'] ?? null) === 'MEI'
                && ($context['masked_email'] ?? '') === 'd***@gmail.com'
                && ! str_contains(json_encode($context), 'SenhaForte10');
        })->once();
});

// ──────────────────────────────────────────────────────────────
// CA-4: e-mail já existente → erro genérico, sem revelar existência
// ──────────────────────────────────────────────────────────────

test('e-mail já cadastrado retorna erro genérico sem revelar enumeração', function () {
    User::factory()->create(['email' => 'existe@example.com', 'role' => 'contratante']);

    $response = cadastroPost(['email' => 'existe@example.com']);

    $response->assertStatus(422);
    $body = $response->json();
    // Mensagem genérica — não cita o campo email nem diz "já cadastrado".
    expect(json_encode($body))->not->toContain('já')
        ->and(json_encode($body))->not->toContain('existe')
        ->and(json_encode($body))->not->toContain('cadastrado e');
    $response->assertJsonPath('message', 'Não foi possível concluir o cadastro. Verifique os dados e tente novamente.');

    // Não criou um segundo usuário.
    expect(User::where('email', 'existe@example.com')->count())->toBe(1);
});

// ──────────────────────────────────────────────────────────────
// CA-5: checkbox de aceite desmarcado → bloqueado server-side
// ──────────────────────────────────────────────────────────────

test('aceite dos termos não marcado é bloqueado no servidor', function () {
    $response = cadastroPost(['termos_aceitos' => false]);
    $response->assertStatus(422)->assertJsonValidationErrors('termos_aceitos');
    expect(User::count())->toBe(0);
});

test('aceite dos termos ausente é bloqueado no servidor', function () {
    $response = cadastroPost(['termos_aceitos' => null]);
    $response->assertStatus(422)->assertJsonValidationErrors('termos_aceitos');
});

// ──────────────────────────────────────────────────────────────
// CA-6: foto inválida (tipo / tamanho)
// ──────────────────────────────────────────────────────────────

test('foto com tipo não permitido é rejeitada', function () {
    $response = cadastroPost(['foto' => UploadedFile::fake()->create('doc.pdf', 100, 'application/pdf')]);
    $response->assertStatus(422)->assertJsonValidationErrors('foto');
});

test('foto acima de 5MB é rejeitada', function () {
    $response = cadastroPost(['foto' => UploadedFile::fake()->create('grande.jpg', 6000, 'image/jpeg')]);
    $response->assertStatus(422)->assertJsonValidationErrors('foto');
});

// Regressão do 413 em homolog: foto realista de celular (~2 MB) tem de ser aceita.
// O limite da app (5 MB) e a infra (nginx client_max_body_size, PHP upload_max_filesize)
// precisam ficar acima disso — ver infra/docker/nginx/nginx.conf e api/Dockerfile.prod.
test('foto de ~2MB (tamanho típico de celular) é aceita', function () {
    $response = cadastroPost([
        'email' => 'foto2mb@example.com',
        'foto' => UploadedFile::fake()->create('foto.jpg', 2048, 'image/jpeg'),
    ]);
    $response->assertCreated();
    expect(User::where('email', 'foto2mb@example.com')->exists())->toBeTrue();
});

test('foto ausente é rejeitada', function () {
    $response = cadastroPost(['foto' => null]);
    $response->assertStatus(422)->assertJsonValidationErrors('foto');
});

// ──────────────────────────────────────────────────────────────
// CA-14: documento (CPF/CNPJ) nunca é coletado nem persistido aqui
// ──────────────────────────────────────────────────────────────

test('não coleta nem persiste documento no pré-cadastro', function () {
    // Cliente tenta injetar documento — deve ser ignorado.
    cadastroPost(['email' => 'doc@example.com', 'documento' => '12345678900', 'documento_tipo' => 'CPF'])
        ->assertCreated();

    $profile = User::where('email', 'doc@example.com')->first()->profissionalProfile;
    expect($profile->documento_encrypted)->toBeNull();
    expect($profile->documento_tipo)->toBeNull();
});

// ──────────────────────────────────────────────────────────────
// CA-2 / CA-11 (núcleo): validações de campo obrigatório e formato
// ──────────────────────────────────────────────────────────────

test('valida campos obrigatórios e formatos', function (array $override, string $field) {
    cadastroPost($override)->assertStatus(422)->assertJsonValidationErrors($field);
})->with([
    'nome curto' => [['name' => 'Jo'], 'name'],
    'nome longo' => [['name' => str_repeat('a', 121)], 'name'],
    'email malformado' => [['email' => 'nao-eh-email'], 'email'],
    'telefone inválido' => [['telefone' => '123'], 'telefone'],
    'cidade ausente' => [['cidade' => ''], 'cidade'],
    'bairro ausente' => [['bairro' => ''], 'bairro'],
    'tipo_pessoa inválido' => [['tipo_pessoa' => 'XX'], 'tipo_pessoa'],
    'funcao inexistente' => [['funcao_id' => 99999], 'funcao_id'],
    'senha curta' => [['password' => 'Ab1', 'password_confirmation' => 'Ab1'], 'password'],
    'senha sem confirmação' => [['password_confirmation' => 'outra-coisa-99'], 'password'],
]);

test('não autentica o usuário após o cadastro', function () {
    cadastroPost(['email' => 'noauth@example.com'])->assertCreated();
    expect(auth('web')->check())->toBeFalse();
});
