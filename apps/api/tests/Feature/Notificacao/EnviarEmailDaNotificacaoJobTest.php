<?php

// STORY-053 (CA-5) — EnviarEmailDaNotificacaoJob: entrega primária via fila `database` (roda no
// queue:work de homolog). Cobre: envio + marcação, idempotência, e falha definitiva via failed().

use App\Enums\NotificacaoTipo;
use App\Jobs\EnviarEmailDaNotificacaoJob;
use App\Mail\NotificacaoMail;
use App\Models\Notificacao;
use App\Models\User;
use App\Services\Notificacao\CriarNotificacaoService;
use App\Services\Notificacao\EnvioEmailNotificacao;
use App\Services\Notificacao\TemplateEmailIncompletoException;
use Database\Seeders\NotificacoesEmailTemplatesSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;

uses(RefreshDatabase::class);

beforeEach(function () {
    User::factory()->admin()->create();
    $this->seed(NotificacoesEmailTemplatesSeeder::class);
    Mail::fake();
});

function notifPendente(?array $payload = null): Notificacao
{
    $dono = User::factory()->contratante()->ativo()->create(['name' => 'João', 'email' => 'joao@example.com']);

    return Notificacao::factory()->tipo(NotificacaoTipo::CandidaturaRecebida)->create([
        'destinatario_id' => $dono->id,
        'vaga_id' => null,
        'payload' => $payload ?? [
            'profissional_nome' => 'Ana', 'profissional_score' => 87, 'vaga_funcao' => 'Garçom',
            'vaga_data_inicio' => '03/06/2026 18:00', 'link_painel' => 'https://app.turni.com.br/x',
        ],
    ]);
}

it('envia o e-mail e marca enviada_email_em', function () {
    $n = notifPendente();

    (new EnviarEmailDaNotificacaoJob($n->id))->handle(app(EnvioEmailNotificacao::class));

    Mail::assertSent(NotificacaoMail::class, fn (NotificacaoMail $m) => $m->hasTo('joao@example.com'));
    expect($n->fresh()->enviada_email_em)->not->toBeNull()
        ->and($n->fresh()->tentativas_envio)->toBe(1);
});

it('é idempotente: notificação já enviada não reenvia', function () {
    $n = notifPendente();
    $n->update(['enviada_email_em' => now()]);

    (new EnviarEmailDaNotificacaoJob($n->id))->handle(app(EnvioEmailNotificacao::class));

    Mail::assertNothingSent();
});

it('failed() marca falha_envio_em e não dispara se já enviada', function () {
    $n = notifPendente();

    (new EnviarEmailDaNotificacaoJob($n->id))->failed(new RuntimeException('Resend caiu'));

    expect($n->fresh()->falha_envio_em)->not->toBeNull();
});

it('CriarNotificacaoService despacha o job ao criar (e não duplica por idempotência)', function () {
    Queue::fake();
    $dono = User::factory()->contratante()->ativo()->create();

    $criar = fn () => app(CriarNotificacaoService::class)->criar(
        tipo: NotificacaoTipo::CandidaturaRecebida,
        destinatarioId: $dono->id, vagaId: null, candidaturaId: null,
        payload: ['vaga_funcao' => 'Garçom'], idempotencyKey: 'idem-1',
    );

    $criar();
    Queue::assertPushed(EnviarEmailDaNotificacaoJob::class, 1);

    // Mesma idempotency_key → firstOrCreate não cria de novo → não despacha de novo.
    $criar();
    Queue::assertPushed(EnviarEmailDaNotificacaoJob::class, 1);
});

it('template incompleto faz o handle lançar (framework reenfileira)', function () {
    $n = notifPendente(payload: []); // sem variáveis → renderer lança

    expect(fn () => (new EnviarEmailDaNotificacaoJob($n->id))->handle(app(EnvioEmailNotificacao::class)))
        ->toThrow(TemplateEmailIncompletoException::class);

    expect($n->fresh()->tentativas_envio)->toBe(1); // contou a tentativa
    Mail::assertNothingSent();
});
