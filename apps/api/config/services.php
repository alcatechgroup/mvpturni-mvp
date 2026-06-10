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

    // STORY-024 CA-4 / IDR-024 — busca de endereço por CEP (fail-soft).
    'viacep' => [
        'base_url' => env('VIACEP_BASE_URL', 'https://viacep.com.br/ws'),
        'timeout' => (int) env('VIACEP_TIMEOUT', 4),
    ],

    // STORY-056 / ADR-016 (CA-3, CA-4, Decisão 2A) — ACL Pagar.me. O DRIVER seleciona
    // base_url + credencial; há um único adapter (PagarmeGateway), sem ramificação por driver.
    //   mock     → container pagarme-mock (default local; 100% sem internet — princípio #6)
    //   sandbox  → ambiente de testes do Pagar.me (CI noturno / homolog — STORY-056-B)
    //   live     → produção (fora do MVP)
    // Segredos reais vêm do Secret Manager em homolog/prod (ADR-004), nunca do código.
    'pagarme' => [
        'driver' => env('PAGARME_DRIVER', 'mock'),
        // PAGARME_BASE_URL explícito tem prioridade (convenção do .env desde STORY-006); na
        // ausência, o driver dá o default (sandbox/live/mock). Segredos só via env/Secret Manager.
        'base_url' => env('PAGARME_BASE_URL') ?: match (env('PAGARME_DRIVER', 'mock')) {
            'sandbox' => 'https://sdx-api.pagar.me/core/v5',
            'live' => 'https://api.pagar.me/core/v5',
            default => 'http://pagarme-mock:8080',
        },
        'secret_key' => env('PAGARME_SECRET_KEY', 'sk_mock'),
        'timeout' => (int) env('PAGARME_TIMEOUT', 15),
        // Segredo compartilhado da assinatura HMAC do webhook entrante (ADR-016 e).
        'webhook_secret' => env('PAGARME_WEBHOOK_SECRET', 'whsec_mock'),
        // STORY-065 (IDR-028) — segredo DEDICADO da chave Pix do snapshot de pix_falhas,
        // COMPARTILHADO com o app admin (cada app tem APP_KEY própria; o Backoffice precisa
        // ler a chave para o tratamento manual — CA-5). Default só para dev/CI (mesmo
        // racional do sk_mock); homolog injeta via Secret Manager.
        'pix_falha_chave_key' => env('PIX_FALHA_CHAVE_KEY', 'base64:QSaMggP0jJQeXLjsVeaVSbzjYRuI/jafz7urwOGT7Mg='),
    ],

    // STORY-093 / ADR-020 (Decisão 3A) · IDR-032 — segredo do canal service-to-service admin→api
    // para o comando "pagar integral" (rotas /api/internal/*; InternalServiceAuth). O admin é um
    // processo separado e NÃO emite o evento in-process TurnoFinalizado, então a captura é
    // single-sourced na api. COMPARTILHADO nos 2 .env (mesmo racional do pix_falha_chave_key/IDR-028);
    // default só para dev/CI, homolog/prod via Secret Manager (ADR-004), nunca do código.
    'internal' => [
        'token' => env('INTERNAL_SERVICE_TOKEN', 'dev-internal-s2s-token-change-me'),
    ],

];
