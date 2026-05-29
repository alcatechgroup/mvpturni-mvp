<?php

namespace App\Providers;

use App\Domain\Email\EnviaEmailTransacional;
use App\Domain\Email\LogEnviaEmailTransacional;
use Illuminate\Support\ServiceProvider;

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
