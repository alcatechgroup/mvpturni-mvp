<?php

// STORY-053 (CA-5) — worker `notificacoes:enviar-emails`: drena a fila implícita, renderiza
// corpo+assunto pelo template ativo e envia via NotificacaoMail. Cobre: envio + marcação,
// interpolação do {prazo_em} no assunto, respeito à fila (não reenvia enviadas/falhadas), e o
// retry por tentativas_envio até falha_envio_em na 3ª tentativa.

use App\Enums\NotificacaoTipo;
use App\Mail\NotificacaoMail;
use App\Models\Notificacao;
use App\Models\User;
use Database\Seeders\NotificacoesEmailTemplatesSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;

uses(RefreshDatabase::class);

beforeEach(function () {
    // O seeder precisa de um admin como autor da versão ativa.
    User::factory()->admin()->create();
    $this->seed(NotificacoesEmailTemplatesSeeder::class);
    Mail::fake();
});

function destinatario(string $nome = 'João', string $email = 'joao@example.com'): User
{
    return User::factory()->contratante()->ativo()->create(['name' => $nome, 'email' => $email]);
}

function pendente(NotificacaoTipo $tipo, User $dono, array $payload): Notificacao
{
    return Notificacao::factory()->tipo($tipo)->create([
        'destinatario_id' => $dono->id,
        'vaga_id' => null,
        'payload' => $payload,
    ]);
}

function payloadCandidatura(): array
{
    return [
        'profissional_nome' => 'Ana', 'profissional_score' => 87, 'vaga_funcao' => 'Garçom',
        'vaga_data_inicio' => '03/06/2026 18:00', 'link_painel' => 'https://app.turni.com.br/x',
    ];
}

it('envia o e-mail das notificações pendentes e marca enviada_email_em', function () {
    $dono = destinatario(email: 'contratante@example.com');
    $n = pendente(NotificacaoTipo::CandidaturaRecebida, $dono, payloadCandidatura());

    $this->artisan('notificacoes:enviar-emails')->assertSuccessful();

    Mail::assertSent(NotificacaoMail::class, fn (NotificacaoMail $m) => $m->hasTo('contratante@example.com')
        && $m->assunto === 'Nova candidatura para sua vaga no Turni');

    expect($n->fresh()->enviada_email_em)->not->toBeNull();
});

it('interpola {prazo_em} no assunto da vaga editada', function () {
    $dono = destinatario();
    pendente(NotificacaoTipo::VagaEditadaMaterial, $dono, [
        'vaga_funcao' => 'Cozinheiro',
        'diff_texto' => 'Valor: R$ 100,00 → R$ 120,00',
        'prazo_em' => '04/06/2026 18:00',
        'link_detalhe' => 'https://app.turni.com.br/vaga/9',
    ]);

    $this->artisan('notificacoes:enviar-emails')->assertSuccessful();

    Mail::assertSent(NotificacaoMail::class, fn (NotificacaoMail $m) => $m->assunto === 'Vaga em que você se candidatou foi alterada — confirme até 04/06/2026 18:00');
});

it('NotificacaoMail monta o envelope e renderiza o layout transacional', function () {
    $mail = new NotificacaoMail('Assunto de teste', [
        'preheader' => 'pre', 'h1' => 'Título do e-mail', 'saudacao' => 'Olá, Ana.',
        'paragrafos' => ['Primeiro parágrafo.'], 'ctaLabel' => 'Abrir', 'ctaUrl' => 'https://app.turni.com.br/x',
        'aviso' => null, 'rodape' => 'Rodapé curto.',
    ]);

    expect($mail->envelope()->subject)->toBe('Assunto de teste');
    expect($mail->render())->toContain('Título do e-mail')->toContain('Abrir');
});

it('não reenvia notificações já enviadas ou com falha definitiva', function () {
    $dono = destinatario();
    Notificacao::factory()->tipo(NotificacaoTipo::CandidaturaRecebida)->emailEnviado()
        ->create(['destinatario_id' => $dono->id, 'vaga_id' => null, 'payload' => payloadCandidatura()]);
    Notificacao::factory()->tipo(NotificacaoTipo::CandidaturaRecebida)
        ->create(['destinatario_id' => $dono->id, 'vaga_id' => null, 'payload' => payloadCandidatura(), 'falha_envio_em' => now()]);

    $this->artisan('notificacoes:enviar-emails')->assertSuccessful();

    Mail::assertNothingSent();
});

it('conta tentativas e marca falha_envio_em na 3ª tentativa quando o template está incompleto', function () {
    $dono = destinatario();
    // payload vazio → renderer lança TemplateEmailIncompletoException → falha.
    $n = pendente(NotificacaoTipo::CandidaturaRecebida, $dono, []);

    $this->artisan('notificacoes:enviar-emails');
    expect($n->fresh()->tentativas_envio)->toBe(1)
        ->and($n->fresh()->falha_envio_em)->toBeNull();

    $this->artisan('notificacoes:enviar-emails');
    expect($n->fresh()->tentativas_envio)->toBe(2)
        ->and($n->fresh()->falha_envio_em)->toBeNull();

    $this->artisan('notificacoes:enviar-emails');
    expect($n->fresh()->tentativas_envio)->toBe(3)
        ->and($n->fresh()->falha_envio_em)->not->toBeNull();

    // A 4ª execução não toca mais (saiu da fila por falha_envio_em).
    $this->artisan('notificacoes:enviar-emails');
    expect($n->fresh()->tentativas_envio)->toBe(3);

    Mail::assertNothingSent();
});
