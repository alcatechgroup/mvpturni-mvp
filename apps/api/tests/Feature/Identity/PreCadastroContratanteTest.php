<?php

// STORY-018 — CA-3, CA-4, CA-5, CA-6, CA-9, CA-12, CA-13 — Pré-cadastro de contratante.

use App\Models\ContratanteProfile;
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
});

// CSRF/stateful são validados no E2E em browser real (CA-9); aqui focamos a lógica.
function cadastroContratantePost(array $overrides = []): TestResponse
{
    $payload = array_merge([
        'name' => 'Maria Souza',
        'email' => 'maria@example.com',
        'telefone' => '(11) 91234-5678',
        'nome_estabelecimento' => 'Bar do Porto',
        'tipo_operacao' => 'bar',
        'cidade' => 'São Paulo',
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
        ->post('/api/cadastro/contratante', $payload);
}

// ──────────────────────────────────────────────────────────────
// CA-3 / CA-9: criação bem-sucedida persiste corretamente
// ──────────────────────────────────────────────────────────────

test('cria contratante pendente_aprovacao com perfil do estabelecimento', function (string $tipo) {
    $response = cadastroContratantePost([
        'email' => $tipo.'@example.com',
        'tipo_operacao' => $tipo,
    ]);

    $response->assertCreated()
        ->assertJson(['success' => true])
        ->assertJsonStructure(['success', 'message']);

    $user = User::where('email', $tipo.'@example.com')->first();
    expect($user)->not->toBeNull();
    expect($user->role)->toBe('contratante');
    expect($user->status)->toBe('pendente_aprovacao');
    expect($user->welcome_seen_at)->toBeNull();
    expect($user->cadastro_completed_at)->toBeNull();

    $profile = $user->contratanteProfile;
    expect($profile)->not->toBeNull();
    expect($profile->nome_estabelecimento)->toBe('Bar do Porto');
    expect($profile->tipo_operacao)->toBe($tipo);
    expect($profile->telefone)->toBe('(11) 91234-5678');
    expect($profile->cidade)->toBe('São Paulo');
    expect($profile->plano)->toBe('member_start'); // default Member Start
    expect($profile->termos_aceitos_at)->not->toBeNull();
    expect($profile->foto_path)->not->toBeNull();
    Storage::disk('local')->assertExists($profile->foto_path);
})->with(['restaurante', 'bar', 'hotel', 'evento', 'catering', 'outro']);

// CA-3: senha com hash Argon2id; nunca volta no response
test('senha é hasheada com argon2id e nunca aparece no response', function () {
    $response = cadastroContratantePost(['email' => 'hash@example.com']);
    $response->assertCreated();

    $user = User::where('email', 'hash@example.com')->first();
    expect($user->password)->not->toBe('SenhaForte10');
    expect($user->password)->toStartWith('$argon2id$');
    expect(password_verify('SenhaForte10', $user->password))->toBeTrue();

    $body = $response->getContent();
    expect($body)->not->toContain('SenhaForte10');
    expect($body)->not->toContain($user->password);
});

// CA-3 / CA-12: não loga senha; loga evento estruturado com e-mail mascarado
test('emite log estruturado user.preregistered com e-mail mascarado e sem senha', function () {
    Log::spy();

    cadastroContratantePost(['email' => 'maria.souza@gmail.com', 'tipo_operacao' => 'hotel'])->assertCreated();

    Log::shouldHaveReceived('info')
        ->withArgs(function ($message, $context = []) {
            return $message === 'user.preregistered'
                && ($context['event'] ?? null) === 'user.preregistered'
                && ($context['role'] ?? null) === 'contratante'
                && ($context['tipo_operacao'] ?? null) === 'hotel'
                && ($context['masked_email'] ?? '') === 'm***@gmail.com'
                && ! str_contains(json_encode($context), 'SenhaForte10');
        })->once();
});

// ──────────────────────────────────────────────────────────────
// CA-4: e-mail já existente → erro genérico, sem revelar existência
// ──────────────────────────────────────────────────────────────

test('e-mail já cadastrado retorna erro genérico sem revelar enumeração', function () {
    User::factory()->create(['email' => 'existe@example.com', 'role' => 'profissional']);

    $response = cadastroContratantePost(['email' => 'existe@example.com']);

    $response->assertStatus(422);
    $body = $response->json();
    expect(json_encode($body))->not->toContain('já')
        ->and(json_encode($body))->not->toContain('existe')
        ->and(json_encode($body))->not->toContain('cadastrado e');
    $response->assertJsonPath('message', 'Não foi possível concluir o cadastro. Verifique os dados e tente novamente.');

    // Não criou um segundo usuário nem um perfil órfão.
    expect(User::where('email', 'existe@example.com')->count())->toBe(1);
    expect(ContratanteProfile::count())->toBe(0);
});

// ──────────────────────────────────────────────────────────────
// CA-5: checkbox de aceite desmarcado → bloqueado server-side
// ──────────────────────────────────────────────────────────────

test('aceite dos termos não marcado é bloqueado no servidor', function () {
    $response = cadastroContratantePost(['termos_aceitos' => false]);
    $response->assertStatus(422)->assertJsonValidationErrors('termos_aceitos');
    expect(User::count())->toBe(0);
});

test('aceite dos termos ausente é bloqueado no servidor', function () {
    $response = cadastroContratantePost(['termos_aceitos' => null]);
    $response->assertStatus(422)->assertJsonValidationErrors('termos_aceitos');
});

// ──────────────────────────────────────────────────────────────
// CA-6: foto inválida (tipo / tamanho)
// ──────────────────────────────────────────────────────────────

test('foto com tipo não permitido é rejeitada', function () {
    $response = cadastroContratantePost(['foto' => UploadedFile::fake()->create('doc.pdf', 100, 'application/pdf')]);
    $response->assertStatus(422)->assertJsonValidationErrors('foto');
});

test('foto acima de 5MB é rejeitada', function () {
    $response = cadastroContratantePost(['foto' => UploadedFile::fake()->create('grande.jpg', 6000, 'image/jpeg')]);
    $response->assertStatus(422)->assertJsonValidationErrors('foto');
});

test('foto de ~2MB (tamanho típico de celular) é aceita', function () {
    $response = cadastroContratantePost([
        'email' => 'foto2mb@example.com',
        'foto' => UploadedFile::fake()->create('foto.jpg', 2048, 'image/jpeg'),
    ]);
    $response->assertCreated();
    expect(User::where('email', 'foto2mb@example.com')->exists())->toBeTrue();
});

test('foto ausente é rejeitada', function () {
    $response = cadastroContratantePost(['foto' => null]);
    $response->assertStatus(422)->assertJsonValidationErrors('foto');
});

// ──────────────────────────────────────────────────────────────
// CA-13: CNPJ/endereço/segmento nunca são coletados nem persistidos aqui
// ──────────────────────────────────────────────────────────────

test('não coleta nem persiste CNPJ, endereço ou segmento no pré-cadastro', function () {
    // Cliente tenta injetar campos de completar cadastro — devem ser ignorados.
    cadastroContratantePost([
        'email' => 'inject@example.com',
        'cnpj' => '12345678000190',
        'cnpj_encrypted' => '12345678000190',
        'endereco_completo' => 'Rua X, 123',
        'segmento' => 'gastronomia',
    ])->assertCreated();

    $profile = User::where('email', 'inject@example.com')->first()->contratanteProfile;
    expect($profile->cnpj_encrypted)->toBeNull();
    expect($profile->endereco_completo)->toBeNull();
});

// ──────────────────────────────────────────────────────────────
// CA-2 / CA-11 (núcleo): validações de campo obrigatório e formato
// ──────────────────────────────────────────────────────────────

test('valida campos obrigatórios e formatos', function (array $override, string $field) {
    cadastroContratantePost($override)->assertStatus(422)->assertJsonValidationErrors($field);
})->with([
    'nome curto' => [['name' => 'Jo'], 'name'],
    'nome longo' => [['name' => str_repeat('a', 121)], 'name'],
    'email malformado' => [['email' => 'nao-eh-email'], 'email'],
    'telefone inválido' => [['telefone' => '123'], 'telefone'],
    'estabelecimento ausente' => [['nome_estabelecimento' => ''], 'nome_estabelecimento'],
    'estabelecimento curto' => [['nome_estabelecimento' => 'A'], 'nome_estabelecimento'],
    'estabelecimento longo' => [['nome_estabelecimento' => str_repeat('a', 201)], 'nome_estabelecimento'],
    'tipo_operacao inválido' => [['tipo_operacao' => 'foobar'], 'tipo_operacao'],
    'tipo_operacao ausente' => [['tipo_operacao' => ''], 'tipo_operacao'],
    'cidade ausente' => [['cidade' => ''], 'cidade'],
    'senha curta' => [['password' => 'Ab1', 'password_confirmation' => 'Ab1'], 'password'],
    'senha sem confirmação' => [['password_confirmation' => 'outra-coisa-99'], 'password'],
]);

test('não autentica o usuário após o cadastro', function () {
    cadastroContratantePost(['email' => 'noauth@example.com'])->assertCreated();
    expect(auth('web')->check())->toBeFalse();
});
