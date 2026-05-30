<?php

use App\Http\Responses\NeutralPasswordResetLinkResponse;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Queue;
use Turni\Domain\Email\EnviarEmailTransacionalJob;
use Turni\Domain\Email\TipoEmail;

/*
 * STORY-021 CA-6/CA-7 — recuperação de senha do Fortify roteada pela ACL de e-mail,
 * resposta anti-enumeração, throttling e TTL de 60 min (ADR-007 §f).
 */

beforeEach(function () {
    // Lock de unicidade (ShouldBeUnique) em cache array — fora da transação do RefreshDatabase.
    config(['cache.default' => 'array']);
});

const NEUTRA = NeutralPasswordResetLinkResponse::MESSAGE;

it('e-mail conhecido recebe recuperacao_senha pela ACL com link e TTL (CA-6)', function () {
    Queue::fake();
    $user = User::factory()->create(['email' => 'existe@teste.local', 'name' => 'Fulano']);

    $this->postJson('/forgot-password', ['email' => $user->email])
        ->assertOk()
        ->assertJson(['message' => NEUTRA]);

    Queue::assertPushed(
        EnviarEmailTransacionalJob::class,
        fn ($job) => $job->email->tipo === TipoEmail::RecuperacaoSenha
            && $job->email->destinatario === 'existe@teste.local'
            && str_contains($job->email->dados['link_redefinicao'], '/reset-password?token=')
            && str_contains($job->email->dados['link_redefinicao'], 'email=existe%40teste.local')
            && $job->email->dados['expiracao_minutos'] === 60,
    );
});

it('e-mail desconhecido devolve a MESMA resposta neutra e não enfileira nada (CA-7)', function () {
    Queue::fake();

    $this->postJson('/forgot-password', ['email' => 'naoexiste@teste.local'])
        ->assertOk()
        ->assertJson(['message' => NEUTRA]);

    Queue::assertNotPushed(EnviarEmailTransacionalJob::class);
});

it('redefine a senha com token válido e a nova senha passa a valer (CA-6)', function () {
    $user = User::factory()->create([
        'email' => 'reset@teste.local',
        'password' => Hash::make('senha-antiga'),
    ]);
    $token = Password::createToken($user);

    $this->postJson('/reset-password', [
        'token' => $token,
        'email' => $user->email,
        'password' => 'NovaSenha@2026',
        'password_confirmation' => 'NovaSenha@2026',
    ])->assertOk();

    $user->refresh();
    expect(Hash::check('NovaSenha@2026', $user->password))->toBeTrue()
        ->and(Hash::check('senha-antiga', $user->password))->toBeFalse();
});

it('token inválido não redefine a senha', function () {
    $user = User::factory()->create([
        'email' => 'reset2@teste.local',
        'password' => Hash::make('senha-antiga'),
    ]);

    $this->postJson('/reset-password', [
        'token' => 'token-falso',
        'email' => $user->email,
        'password' => 'NovaSenha@2026',
        'password_confirmation' => 'NovaSenha@2026',
    ])->assertStatus(422);

    $user->refresh();
    expect(Hash::check('senha-antiga', $user->password))->toBeTrue();
});

it('pedido repetido é throttled e mantém a resposta neutra, sem 2º e-mail (ADR-007 §f)', function () {
    Queue::fake();
    $user = User::factory()->create(['email' => 'flood@teste.local']);

    $this->postJson('/forgot-password', ['email' => $user->email])->assertOk();
    $this->postJson('/forgot-password', ['email' => $user->email])
        ->assertOk()
        ->assertJson(['message' => NEUTRA]);

    Queue::assertPushed(EnviarEmailTransacionalJob::class, 1);
});

it('o link de reset expira em 60 minutos (ADR-007 §f)', function () {
    expect(config('auth.passwords.users.expire'))->toBe(60);
});
