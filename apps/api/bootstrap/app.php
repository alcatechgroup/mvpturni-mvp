<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Cloud Run termina o TLS na borda e encaminha HTTP com X-Forwarded-Proto=https.
        // Confia no proxy serverless para o Laravel gerar URLs https:// (links de e-mail,
        // cookies secure, redirects) e tratar o request como seguro. Paridade com o admin.
        $middleware->trustProxies(at: '*', headers: Request::HEADER_X_FORWARDED_FOR
            | Request::HEADER_X_FORWARDED_HOST
            | Request::HEADER_X_FORWARDED_PORT
            | Request::HEADER_X_FORWARDED_PROTO);

        // Sanctum SPA stateful API (ADR-007 §b): injeta EnsureFrontendRequestsAreStateful
        // no grupo `api` para que o WebApp Flutter use sessão por cookie same-site.
        $middleware->statefulApi();

        // As rotas Fortify de reset (forgot-password/reset-password) ficam no grupo `web`
        // (CSRF por token). O WebApp Flutter same-origin não envia X-XSRF-TOKEN (mesmo
        // modelo do /api/login, que roda só com StartSession e sem CSRF — STORY-021 CA-13b).
        // Excluímos esses 2 paths do CSRF; anti-enumeração + throttling do Fortify seguem
        // protegendo. Firebase reescreve /forgot-password e /reset-password para este api.
        $middleware->validateCsrfTokens(except: [
            'forgot-password',
            'reset-password',
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            // api/* sempre JSON; e qualquer requisição que pede JSON (Accept) também —
            // as rotas do Fortify (login, forgot/reset-password) ficam na raiz, não em
            // api/*, e o WebApp Flutter as consome esperando erros em JSON (STORY-021 CA-6).
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();
