<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    // STORY-065 (IDR-028) — segredo DEDICADO da chave Pix do snapshot de pix_falhas,
    // COMPARTILHADO com o app api (que o escreve; aqui só leitura para o tratamento
    // manual — CA-5). Default só para dev/CI; homolog injeta via Secret Manager.
    'pix_falha' => [
        'chave_key' => env('PIX_FALHA_CHAVE_KEY', 'base64:QSaMggP0jJQeXLjsVeaVSbzjYRuI/jafz7urwOGT7Mg='),
    ],

    // STORY-096 (IDR-032) — canal service-to-service admin→api do comando "pagar integral".
    // O admin é CLIENTE: a captura+Pix é single-sourced na api (ADR-020 Decisão 3), disparada
    // por evento in-process que o backoffice não emite. `api.internal_url` aponta para o app api
    // (no compose: http://api:8000; homolog/prod: URL do Cloud Run, via Terraform). `internal.token`
    // é o segredo compartilhado (mesmo valor nos 2 .env; default só dev/CI, homolog via Secret
    // Manager — mesmo racional do pix_falha.chave_key).
    'api' => [
        'internal_url' => env('INTERNAL_API_URL', 'http://api:8000'),
    ],

    'internal' => [
        'token' => env('INTERNAL_SERVICE_TOKEN', 'dev-internal-s2s-token-change-me'),
    ],

];
