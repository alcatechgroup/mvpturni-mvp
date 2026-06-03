<?php

namespace App\Listeners;

/**
 * STORY-053 — URLs absolutas do WebApp para os CTAs dos e-mails (SCREEN-STORY-053 §2). Base em
 * `app.webapp_url` (host da WebApp; mesmo fallback do EnviarLembretesCadastroCommand). O CTA
 * in-app navega pela rota interna (derivada de tipo+vaga_id no cliente), não por estas URLs.
 */
final class LinksWebApp
{
    private static function base(): string
    {
        return rtrim((string) config('app.webapp_url', config('app.url')), '/');
    }

    public static function painelCandidatos(int $vagaId): string
    {
        return self::base()."/contratante/vagas/{$vagaId}/candidatos";
    }

    public static function detalheVaga(int $vagaId): string
    {
        return self::base()."/vaga/{$vagaId}";
    }

    public static function feed(): string
    {
        return self::base().'/feed';
    }
}
