<?php

namespace App\Providers;

use App\Email\MailEnviaEmailTransacional;
use App\Events\AvaliacaoRegistrada;
use App\Events\CandidaturaEnviada;
use App\Events\CheckinSolicitado;
use App\Events\CheckoutSolicitado;
use App\Events\DisputaAberta;
use App\Events\Pagamento\PixEnviado;
use App\Events\Pagamento\PixFalhou;
use App\Events\TurnoCancelado;
use App\Events\TurnoCriado;
use App\Events\TurnoFinalizado;
use App\Events\TurnoIniciado;
use App\Events\TurnoNoShow;
use App\Events\VagaCancelada;
use App\Events\VagaEditadaMaterialmente;
use App\Listeners\HandleCandidaturaEnviada;
use App\Listeners\HandlePixEnviado;
use App\Listeners\HandlePixFalhou;
use App\Listeners\HandleVagaCancelada;
use App\Listeners\HandleVagaEditadaMaterialmente;
use App\Listeners\NotificarAvaliacaoPendente;
use App\Listeners\NotificarCheckinSolicitado;
use App\Listeners\NotificarCheckoutSolicitado;
use App\Listeners\NotificarDisputaAberta;
use App\Listeners\NotificarPixEnviado;
use App\Listeners\NotificarTurnoCancelado;
use App\Listeners\NotificarTurnoCriado;
use App\Listeners\NotificarTurnoFinalizado;
use App\Listeners\NotificarTurnoIniciado;
use App\Listeners\NotificarTurnoNoShow;
use App\Listeners\RecalcularReputacaoListener;
use App\Listeners\TurnoCanceladoListener;
use App\Listeners\TurnoFinalizadoListener;
use App\Listeners\TurnoNoShowListener;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;
use Turni\Domain\Email\EnviaEmailTransacional;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // ACL de e-mail transacional (ADR-011 §b; IDR-015). O worker roda no
        // contexto do `api` (docker-compose), então é AQUI que o job despachado
        // pelo admin é processado — o adapter real precisa estar ligado neste app.
        // Provedor real selecionado por MAIL_MAILER (Resend homolog/prod, Mailpit dev).
        $this->app->bind(EnviaEmailTransacional::class, MailEnviaEmailTransacional::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // STORY-053 (CA-2/3/4) — listeners dos 3 eventos de domínio que criam notificações
        // in-app + alimentam a fila de e-mail. Registro explícito (sem event discovery): os
        // eventos são despachados síncronos dentro da transação que os origina, então a
        // notificação é transacionalmente consistente com a candidatura/edição/cancelamento.
        Event::listen(CandidaturaEnviada::class, HandleCandidaturaEnviada::class);
        Event::listen(VagaEditadaMaterialmente::class, HandleVagaEditadaMaterialmente::class);
        Event::listen(VagaCancelada::class, HandleVagaCancelada::class);

        // STORY-065 (CA-1) — fim do turno dispara o ciclo financeiro (captura + Pix) em
        // job na fila database; o listener é fino e o job re-verifica o estado (CA-9).
        Event::listen(TurnoFinalizado::class, TurnoFinalizadoListener::class);

        // STORY-065 (CA-4..6) — o webhook do gateway é a fonte de verdade do pagamento:
        // confirmação vira `pix.enviado` (timeline + card); falha vira caso na fila do
        // admin (`pix_falhas`) — inclusive falha reportada após sucesso aparente.
        Event::listen(PixEnviado::class, HandlePixEnviado::class);
        Event::listen(PixFalhou::class, HandlePixFalhou::class);

        // STORY-066 (CA-2/CA-6) — cancelamento e no-show liberam a pré-autorização em job
        // na fila database (listeners finos; o job re-verifica o estado e é idempotente).
        Event::listen(TurnoCancelado::class, TurnoCanceladoListener::class);
        Event::listen(TurnoNoShow::class, TurnoNoShowListener::class);

        // STORY-067 (CA-1..3) — os 8 eventos do turno criam notificação in-app + e-mail na
        // fila (reuso do CriarNotificacaoService/053). Idempotência por chave; eventos
        // disparados pós-commit pelos services de origem. PixEnviado/TurnoFinalizado/
        // TurnoCancelado/TurnoNoShow acumulam um 2º listener — responsabilidade separada.
        Event::listen(TurnoCriado::class, NotificarTurnoCriado::class);
        Event::listen(CheckinSolicitado::class, NotificarCheckinSolicitado::class);
        Event::listen(TurnoIniciado::class, NotificarTurnoIniciado::class);
        Event::listen(CheckoutSolicitado::class, NotificarCheckoutSolicitado::class);
        Event::listen(TurnoFinalizado::class, NotificarTurnoFinalizado::class);
        // STORY-085 (CA-2) — 3º listener do mesmo evento: "avalie seu turno" aos dois lados.
        Event::listen(TurnoFinalizado::class, NotificarAvaliacaoPendente::class);
        Event::listen(PixEnviado::class, NotificarPixEnviado::class);
        Event::listen(TurnoCancelado::class, NotificarTurnoCancelado::class);
        Event::listen(TurnoNoShow::class, NotificarTurnoNoShow::class);

        // STORY-092 (CA-6 / ADR-020 Decisão 4) — abertura de disputa notifica o PROFISSIONAL
        // (in-app + e-mail, SLA 30 min). Evento NOVO (não reusa TurnoFinalizado: a abertura não
        // finaliza nem captura). Registro explícito (discovery off); evento disparado pós-commit
        // pelo AbrirDisputaService; idempotente pela chave do CriarNotificacaoService.
        Event::listen(DisputaAberta::class, NotificarDisputaAberta::class);

        // STORY-085 (CA-4/CA-5) — avaliação registrada dispara o motor de reputação SÍNCRONO
        // (ADR-019 Decisão 3/4): recomputa score/XP/nível do avaliado dentro da MESMA transação
        // que inseriu a avaliação. Idempotente por construção (recompute, não delta).
        Event::listen(AvaliacaoRegistrada::class, RecalcularReputacaoListener::class);
    }
}
