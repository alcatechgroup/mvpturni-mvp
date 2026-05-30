<?php

namespace App\Providers;

use App\Email\MailEnviaEmailTransacional;
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
        //
    }
}
