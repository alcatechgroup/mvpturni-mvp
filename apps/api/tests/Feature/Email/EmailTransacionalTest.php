<?php

use App\Email\MailEnviaEmailTransacional;
use App\Mail\TransacionalMail;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Queue;
use Turni\Domain\Email\EmailTransacional;
use Turni\Domain\Email\EmailTransacionalException;
use Turni\Domain\Email\EnviaEmailTransacional;
use Turni\Domain\Email\EnviarEmailTransacionalJob;
use Turni\Domain\Email\TipoEmail;

/*
 * Cobertura da STORY-021 (CA-4, CA-9, CA-10, CA-11, CA-14) e dos identificadores
 * estáveis do SCREEN-STORY-021 §7. Render via Mailable, mascaramento no adapter,
 * relançamento de exceção e idempotência do job.
 */

beforeEach(function () {
    // O docker-compose injeta CACHE_STORE/MAIL_FROM via env_file ($_SERVER tem
    // precedência sobre o <env> do phpunit), então fixamos aqui em runtime:
    //  - mail.from = remetente canônico (ADR-011 §d) para o assertFrom;
    //  - cache.default = array para o lock de unicidade (ShouldBeUnique) não tocar
    //    a tabela cache_locks dentro da transação do RefreshDatabase.
    config([
        'cache.default' => 'array',
        'mail.from.address' => 'no-reply@mail.turni.com.br',
        'mail.from.name' => 'Turni',
    ]);
});

// ── Render do Mailable por tipo (SCREEN §7) ────────────────────────────────

it('renderiza aprovacao_concedida com assunto, from, H1, nome e CTA (HTML + texto)', function () {
    $email = new EmailTransacional(
        destinatario: 'maria@example.com',
        tipo: TipoEmail::AprovacaoConcedida,
        dados: ['nome' => 'Maria', 'link_acesso' => 'https://app.homolog.turni.com.br/login'],
    );

    $mailable = new TransacionalMail($email);

    $mailable->assertHasSubject('Seu cadastro foi aprovado — acesse o Turni');
    $mailable->assertFrom('no-reply@mail.turni.com.br');
    $mailable->assertSeeInHtml('Cadastro aprovado', false);
    $mailable->assertSeeInHtml('Olá, Maria.', false);
    $mailable->assertSeeInHtml('https://app.homolog.turni.com.br/login', false);
    $mailable->assertSeeInText('Cadastro aprovado');
    $mailable->assertSeeInText('Olá, Maria.');
    $mailable->assertSeeInText('https://app.homolog.turni.com.br/login');
});

it('renderiza lembrete_completar_cadastro com assunto e CTA corretos', function () {
    $email = new EmailTransacional(
        destinatario: 'joao@example.com',
        tipo: TipoEmail::LembreteCompletarCadastro,
        dados: ['nome' => 'João', 'link_completar' => 'https://app.homolog.turni.com.br/login', 'horas_pendente' => 120],
    );

    $mailable = new TransacionalMail($email);

    $mailable->assertHasSubject('Complete seu cadastro no Turni');
    $mailable->assertSeeInHtml('Falta completar seu cadastro', false);
    $mailable->assertSeeInHtml('Completar cadastro', false);
    // Tom (SCREEN §5.2): horas_pendente NÃO aparece no corpo.
    $mailable->assertDontSeeInHtml('120', false);
    $mailable->assertDontSeeInText('120');
});

it('renderiza recuperacao_senha com TTL e aviso de segurança', function () {
    $email = new EmailTransacional(
        destinatario: 'maria@example.com',
        tipo: TipoEmail::RecuperacaoSenha,
        dados: ['nome' => 'Maria', 'link_redefinicao' => 'https://app.homolog.turni.com.br/reset?token=abc', 'expiracao_minutos' => 60],
    );

    $mailable = new TransacionalMail($email);

    $mailable->assertHasSubject('Redefina sua senha no Turni');
    $mailable->assertSeeInHtml('Redefinir senha', false);
    $mailable->assertSeeInHtml('expira em 60 minutos', false);
    $mailable->assertSeeInHtml('ignore este e-mail', false);
    $mailable->assertSeeInText('expira em 60 minutos');
    $mailable->assertSeeInText('https://app.homolog.turni.com.br/reset?token=abc');
});

it('usa fallback "Olá." quando o nome está ausente (SCREEN §5 borda)', function () {
    $email = new EmailTransacional(
        destinatario: 'sem-nome@example.com',
        tipo: TipoEmail::AprovacaoConcedida,
        dados: ['link_acesso' => 'https://app.homolog.turni.com.br/login'],
    );

    $mailable = new TransacionalMail($email);

    $mailable->assertSeeInHtml('Olá.', false);
    $mailable->assertDontSeeInHtml('Olá, .', false);
    $mailable->assertSeeInText('Olá.');
});

// ── Adapter: envio, mascaramento (CA-9) e relançamento de exceção (CA-8) ─────

it('envia pelo Mail e loga email.sent com destinatário mascarado (CA-9)', function () {
    Mail::fake();
    $logs = capturaLogs();

    $email = new EmailTransacional(
        destinatario: 'maria.silva@example.com',
        tipo: TipoEmail::AprovacaoConcedida,
        dados: ['nome' => 'Maria', 'link_acesso' => 'https://app.homolog.turni.com.br/login'],
    );

    (new MailEnviaEmailTransacional())->enviar($email);

    Mail::assertSent(TransacionalMail::class, fn ($m) => $m->hasTo('maria.silva@example.com'));

    $sent = collect($logs)->firstWhere('message', 'email.sent');
    expect($sent)->not->toBeNull()
        ->and($sent['context']['destinatario'])->toBe('m•••@example.com')
        ->and($sent['context']['tipo'])->toBe('aprovacao_concedida');
    // O e-mail em claro NUNCA aparece no log (LGPD/ADR-008).
    expect($sent['context'])->not->toContain('maria.silva@example.com');
});

it('relança falha do transporte como EmailTransacionalException e loga email.failed mascarado', function () {
    Mail::shouldReceive('to->send')->andThrow(new RuntimeException('SMTP caiu'));
    $logs = capturaLogs();

    $email = new EmailTransacional(
        destinatario: 'maria.silva@example.com',
        tipo: TipoEmail::AprovacaoConcedida,
        dados: ['nome' => 'Maria', 'link_acesso' => 'x'],
    );

    expect(fn () => (new MailEnviaEmailTransacional())->enviar($email))
        ->toThrow(EmailTransacionalException::class);

    $failed = collect($logs)->firstWhere('message', 'email.failed');
    expect($failed)->not->toBeNull()
        ->and($failed['context']['destinatario'])->toBe('m•••@example.com');
});

// ── Idempotência do job (CA-14) ──────────────────────────────────────────────

it('uniqueId deriva da idempotencyKey e deduplica o despacho (CA-14)', function () {
    Queue::fake();

    $email = new EmailTransacional(
        destinatario: 'maria@example.com',
        tipo: TipoEmail::AprovacaoConcedida,
        dados: ['nome' => 'Maria', 'link_acesso' => 'x'],
        idempotencyKey: 'aprovacao_concedida:42',
    );

    expect((new EnviarEmailTransacionalJob($email))->uniqueId())->toBe('aprovacao_concedida:42');

    EnviarEmailTransacionalJob::dispatch($email);
    EnviarEmailTransacionalJob::dispatch($email);

    Queue::assertPushed(EnviarEmailTransacionalJob::class, 1);
});

it('sem idempotencyKey, cada despacho é único (não deduplica)', function () {
    $email = new EmailTransacional(
        destinatario: 'maria@example.com',
        tipo: TipoEmail::RecuperacaoSenha,
        dados: ['nome' => 'Maria', 'link_redefinicao' => 'x'],
    );

    $a = (new EnviarEmailTransacionalJob($email))->uniqueId();
    $b = (new EnviarEmailTransacionalJob($email))->uniqueId();

    expect($a)->not->toBe($b);
});

// ── Dead letter / alerta (CA-8, ADR-011 §g) ──────────────────────────────────

it('aprovação esgotada loga ERROR com event=email.aprovacao.falhou mascarado', function () {
    $logs = capturaLogs();

    (new EnviarEmailTransacionalJob(new EmailTransacional(
        destinatario: 'maria.silva@example.com',
        tipo: TipoEmail::AprovacaoConcedida,
        dados: ['nome' => 'Maria'],
    )))->failed(new RuntimeException('estourou'));

    $rec = collect($logs)->firstWhere('message', 'email.aprovacao.falhou');
    expect($rec)->not->toBeNull()
        ->and($rec['context']['event'])->toBe('email.aprovacao.falhou')
        ->and($rec['context']['destinatario'])->toBe('m•••@example.com');
});

it('lembrete esgotado loga apenas WARNING (não crítico)', function () {
    $logs = capturaLogs();

    (new EnviarEmailTransacionalJob(new EmailTransacional(
        destinatario: 'joao@example.com',
        tipo: TipoEmail::LembreteCompletarCadastro,
        dados: [],
    )))->failed(new RuntimeException('estourou'));

    expect(collect($logs)->firstWhere('message', 'email.lembrete.falhou'))->not->toBeNull();
});

it('o job enfileira na conexão database e resolve a ACL do container', function () {
    $job = new EnviarEmailTransacionalJob(new EmailTransacional(
        destinatario: 'a@b.com',
        tipo: TipoEmail::AprovacaoConcedida,
        dados: [],
    ));

    expect($job->connection)->toBe('database')
        ->and($job->tries)->toBe(3)
        ->and($job->backoff)->toBe([30, 300, 1800]);

    // O `api` (contexto do worker) DEVE conseguir resolver o adapter real (IDR-015).
    expect(app(EnviaEmailTransacional::class))->toBeInstanceOf(MailEnviaEmailTransacional::class);
});

/**
 * Captura logs em memória para inspeção (mascaramento). Devolve um ArrayObject
 * (passado por handle) que o listener vai preenchendo a cada registro.
 */
function capturaLogs(): ArrayObject
{
    $logs = new ArrayObject();
    Log::listen(function ($log) use ($logs) {
        $logs->append(['message' => $log->message, 'context' => $log->context]);
    });

    return $logs;
}
