<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Turni\Domain\Email\EnviaEmailTransacional;
use Turni\Domain\Email\LogEnviaEmailTransacional;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // ACL de e-mail transacional (ADR-011). STORY-019 usa o adapter log-only;
        // STORY-021 substitui por LogEnviaEmailTransacional → adapter Resend.
        $this->app->bind(EnviaEmailTransacional::class, LogEnviaEmailTransacional::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
