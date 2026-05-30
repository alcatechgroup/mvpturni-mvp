<?php

use App\Models\AdminAuditLog;
use App\Models\CadastroLembrete;
use App\Models\User;
use Illuminate\Support\Facades\Queue;
use Turni\Domain\Email\EnviarEmailTransacionalJob;
use Turni\Domain\Email\TipoEmail;

/*
 * STORY-021 CA-5 — job de lembrete de completar cadastro (48h/5d/14d), tabela
 * auxiliar idempotente, teto de 3 e observação no audit log após o 3º.
 */

beforeEach(function () {
    // Lock de unicidade (ShouldBeUnique) em cache array — não tocar cache_locks
    // dentro da transação do RefreshDatabase (mesmo motivo do EmailTransacionalTest).
    config(['cache.default' => 'array']);
    Queue::fake();
});

/** Cria um usuário elegível (liberado, welcome visto, cadastro pendente) aprovado há X. */
function usuarioElegivel(string $aprovadoHa): User
{
    return User::factory()->liberadoWelcomeVisto()->create([
        'aprovado_em' => now()->sub($aprovadoHa),
    ]);
}

function rodarLembretes(): void
{
    test()->artisan('lembretes:cadastro')->assertSuccessful();
}

// ── Elegibilidade ────────────────────────────────────────────────────────────

it('envia o 1º lembrete após 48h e registra na tabela auxiliar', function () {
    $user = usuarioElegivel('50 hours');

    rodarLembretes();

    Queue::assertPushed(
        EnviarEmailTransacionalJob::class,
        fn ($job) => $job->email->tipo === TipoEmail::LembreteCompletarCadastro
            && $job->email->destinatario === $user->email
            && $job->email->idempotencyKey === "lembrete_completar_cadastro:{$user->id}:1",
    );
    expect(CadastroLembrete::where('user_id', $user->id)->where('numero', 1)->exists())->toBeTrue();
});

it('não envia antes de 48h', function () {
    usuarioElegivel('47 hours');

    rodarLembretes();

    Queue::assertNotPushed(EnviarEmailTransacionalJob::class);
});

it('não envia para quem já completou o cadastro', function () {
    User::factory()->liberadoWelcomeVisto()->create([
        'aprovado_em' => now()->subDays(10),
        'cadastro_completed_at' => now(),
    ]);

    rodarLembretes();

    Queue::assertNotPushed(EnviarEmailTransacionalJob::class);
});

it('não envia para quem ainda não viu a welcome', function () {
    User::factory()->liberado()->create([
        'aprovado_em' => now()->subDays(10),
        'welcome_seen_at' => null,
    ]);

    rodarLembretes();

    Queue::assertNotPushed(EnviarEmailTransacionalJob::class);
});

it('não envia para cadastro pendente de aprovação', function () {
    User::factory()->pendenteAprovacao()->create();

    rodarLembretes();

    Queue::assertNotPushed(EnviarEmailTransacionalJob::class);
});

// ── Progressão das janelas 48h → 5d → 14d ────────────────────────────────────

it('envia o 2º lembrete aos 5 dias quando o 1º já foi enviado', function () {
    $user = usuarioElegivel('6 days');
    CadastroLembrete::create(['user_id' => $user->id, 'numero' => 1, 'enviado_em' => now()->subDays(4)]);

    rodarLembretes();

    Queue::assertPushed(
        EnviarEmailTransacionalJob::class,
        fn ($job) => $job->email->idempotencyKey === "lembrete_completar_cadastro:{$user->id}:2",
    );
});

it('envia o 3º lembrete aos 14 dias e grava a observação de expiração no audit log', function () {
    $user = usuarioElegivel('15 days');
    CadastroLembrete::create(['user_id' => $user->id, 'numero' => 1, 'enviado_em' => now()->subDays(13)]);
    CadastroLembrete::create(['user_id' => $user->id, 'numero' => 2, 'enviado_em' => now()->subDays(10)]);

    rodarLembretes();

    Queue::assertPushed(
        EnviarEmailTransacionalJob::class,
        fn ($job) => $job->email->idempotencyKey === "lembrete_completar_cadastro:{$user->id}:3",
    );
    expect(AdminAuditLog::where('action', 'admin.user.cadastro_pendente_expirado')
        ->where('target_id', $user->id)->count())->toBe(1);
});

// ── Teto e idempotência ──────────────────────────────────────────────────────

it('para de enviar após o 3º lembrete (teto de 3)', function () {
    $user = usuarioElegivel('30 days');
    foreach ([1, 2, 3] as $n) {
        CadastroLembrete::create(['user_id' => $user->id, 'numero' => $n, 'enviado_em' => now()->subDays(20 - $n)]);
    }

    rodarLembretes();

    Queue::assertNotPushed(EnviarEmailTransacionalJob::class);
});

it('é idempotente: rodar 2× no mesmo dia não reenvia o mesmo lembrete', function () {
    $user = usuarioElegivel('50 hours');

    rodarLembretes();
    rodarLembretes();

    Queue::assertPushed(EnviarEmailTransacionalJob::class, 1);
    expect(CadastroLembrete::where('user_id', $user->id)->count())->toBe(1);
});
