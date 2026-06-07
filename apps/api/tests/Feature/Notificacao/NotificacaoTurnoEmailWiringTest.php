<?php

// STORY-067 (CA-5/CA-6) — wiring fim-a-fim dos 8 tipos: evento de domínio → notificação →
// template seedado resolvido pelo slug → corpo renderizado SEM placeholder faltando (o
// renderer lança TemplateEmailIncompletoException se o payload do listener não cobre o
// texto-seed — este teste trava o contrato payload⇆template). Assunto canônico interpolado.

use App\Enums\NotificacaoTipo;
use App\Enums\TurnoStatus;
use App\Events\CheckinSolicitado;
use App\Events\CheckoutSolicitado;
use App\Events\Pagamento\PixEnviado;
use App\Events\TurnoCancelado;
use App\Events\TurnoCriado;
use App\Events\TurnoFinalizado;
use App\Events\TurnoIniciado;
use App\Events\TurnoNoShow;
use App\Models\ContratanteProfile;
use App\Models\Funcao;
use App\Models\Notificacao;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use App\Services\Notificacao\EnvioEmailNotificacao;
use Database\Seeders\NotificacoesEmailTemplatesSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

uses(RefreshDatabase::class);

beforeEach(function () {
    User::factory()->admin()->create();
    $this->seed(NotificacoesEmailTemplatesSeeder::class);
    Mail::fake();
});

function turnoWiring(): Turno
{
    $vaga = Vaga::factory()->create([
        'funcao_id' => Funcao::factory()->create(['nome' => 'Garçom'])->id,
    ]);

    $turno = Turno::factory()->status(TurnoStatus::Confirmado)->create([
        'vaga_id' => $vaga->id,
        'contratante_id' => $vaga->contratante_id,
        'estabelecimento_id' => $vaga->contratante_id,
        'valor' => 200.00,
        'taxa_turni' => 30.00,
        'total_contratante' => 230.00,
    ]);

    ContratanteProfile::create([
        'user_id' => $turno->contratante_id,
        'nome_estabelecimento' => 'Restaurante Vela Ltda',
    ]);

    return $turno;
}

it('renderiza e envia o e-mail dos 8 tipos sem placeholder faltando (CA-6)', function () {
    $turno = turnoWiring();

    TurnoCriado::dispatch($turno->id);
    CheckinSolicitado::dispatch($turno->id, (string) Str::uuid7());
    TurnoIniciado::dispatch($turno->id);
    CheckoutSolicitado::dispatch($turno->id, (string) Str::uuid7());
    TurnoFinalizado::dispatch($turno->id);
    PixEnviado::dispatch($turno->id, 'evt_1', []);
    TurnoCancelado::dispatch($turno->id, 'emp', 'Evento cancelado');
    TurnoNoShow::dispatch($turno->id);

    // 8 tipos; no_show gera 2 linhas (ambos os lados) → 9 notificações de turno.
    $notificacoes = Notificacao::whereNotIn('tipo', [
        NotificacaoTipo::CandidaturaRecebida,
        NotificacaoTipo::VagaEditadaMaterial,
        NotificacaoTipo::VagaCancelada,
        NotificacaoTipo::VagaEditadaMaterialCandidaturaMantida,
        NotificacaoTipo::VagaEditadaMaterialCandidaturaRetirada,
    ])->get();

    expect($notificacoes)->toHaveCount(9)
        ->and($notificacoes->pluck('tipo')->unique())->toHaveCount(8);

    $envio = app(EnvioEmailNotificacao::class);

    foreach ($notificacoes as $n) {
        // Placeholder ausente => TemplateEmailIncompletoException; aqui NÃO pode lançar.
        $envio->enviar($n->fresh()->load('destinatario'));

        expect($n->fresh()->enviada_email_em)->not->toBeNull();
    }
});

it('interpola o assunto canônico com o payload (sem {chave} sobrando)', function () {
    $turno = turnoWiring();

    TurnoCriado::dispatch($turno->id);
    PixEnviado::dispatch($turno->id, 'evt_1', []);

    $envio = app(EnvioEmailNotificacao::class);

    $confirmado = Notificacao::where('tipo', NotificacaoTipo::TurnoConfirmado)->first();
    $pix = Notificacao::where('tipo', NotificacaoTipo::PixEnviado)->first();

    expect($envio->assunto($confirmado->tipo, $confirmado->payload))
        ->toContain('Turno confirmado — Garçom em ')
        ->not->toContain('{')
        ->and($envio->assunto($pix->tipo, $pix->payload))
        ->toBe('Pix enviado — R$ 200,00 do turno de Garçom');
});
