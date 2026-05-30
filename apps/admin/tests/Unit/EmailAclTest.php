<?php

// STORY-019 — ACL de e-mail (ADR-011): VO de mascaramento, job e adapter log-only (CA-7).

use Illuminate\Support\Facades\Log;
use Turni\Domain\Email\EmailTransacional;
use Turni\Domain\Email\EnviaEmailTransacional;
use Turni\Domain\Email\EnviarEmailTransacionalJob;
use Turni\Domain\Email\LogEnviaEmailTransacional;
use Turni\Domain\Email\TipoEmail;

test('mascara o e-mail preservando inicial e domínio', function () {
    $vo = new EmailTransacional('carlos@exemplo.com', TipoEmail::AprovacaoConcedida);
    expect($vo->destinatarioMascarado())->toBe('c•••@exemplo.com');
});

test('mascara e-mail sem domínio sem quebrar', function () {
    $vo = new EmailTransacional('semarroba', TipoEmail::AprovacaoConcedida);
    expect($vo->destinatarioMascarado())->toBe('s•••');
});

test('adapter log-only registra dispatch com e-mail mascarado e sem PII', function () {
    Log::spy();

    (new LogEnviaEmailTransacional)->enviar(
        new EmailTransacional('novo@exemplo.com', TipoEmail::AprovacaoConcedida, ['nome' => 'Novo'])
    );

    Log::shouldHaveReceived('info')->once()->withArgs(function ($message, $context) {
        return $message === 'email.transacional.dispatched'
            && $context['tipo'] === 'aprovacao_concedida'
            && $context['destinatario'] === 'n•••@exemplo.com'
            && ! str_contains(json_encode($context), 'novo@exemplo.com'); // nunca PII em claro
    });
});

test('job resolve a ACL do container e delega o envio', function () {
    $email = new EmailTransacional('x@y.com', TipoEmail::AprovacaoConcedida);
    $gateway = Mockery::mock(EnviaEmailTransacional::class);
    $gateway->shouldReceive('enviar')->once()->with($email);

    (new EnviarEmailTransacionalJob($email))->handle($gateway);
});

test('job é configurado para a fila database com 3 tentativas (ADR-011)', function () {
    $job = new EnviarEmailTransacionalJob(new EmailTransacional('x@y.com', TipoEmail::AprovacaoConcedida));
    expect($job->connection)->toBe('database')
        ->and($job->tries)->toBe(3)
        ->and($job->backoff)->toBe([30, 300, 1800]);
});
