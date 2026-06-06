<?php

namespace App\Providers;

use App\Email\MailEnviaEmailTransacional;
use App\Events\CandidaturaEnviada;
use App\Events\TurnoFinalizado;
use App\Events\VagaCancelada;
use App\Events\VagaEditadaMaterialmente;
use App\Listeners\HandleCandidaturaEnviada;
use App\Listeners\HandleVagaCancelada;
use App\Listeners\HandleVagaEditadaMaterialmente;
use App\Listeners\TurnoFinalizadoListener;
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
    }
}
