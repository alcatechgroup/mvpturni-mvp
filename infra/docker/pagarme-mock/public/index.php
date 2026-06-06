<?php

// Mock do Pagar.me (ADR-005 / ADR-016 CA-4, CA-7). Simula o contrato HTTP usado pela ACL
// (App\Domain\Pagamento\Pagarme\PagarmeGateway) e DEVOLVE o webhook assinado ao `api`, fechando
// o ciclo pré-auth → captura → Pix → webhook 100% local, sem internet (princípio #6).
//
// NÃO é o Pagar.me real: este mock é o ambiente DEFAULT de dev/CI. A fidelidade ao sandbox é
// guardada pelo contract test noturno da STORY-056-B (ADR-016 h). Versão do contrato simulada:
//   simula API estilo Pagar.me Core v5, capturada em 2026-06-04 (STORY-056-A).
//
// Endpoints (espelho do que o adapter chama):
//   POST /orders                  → cria order + charge pré-autorizado     → webhook charge.pending
//   POST /charges/{id}/capture    → captura (total ou parcial via amount)  → webhook charge.paid
//   POST /charges/{id}/cancel     → libera/estorna a pré-autorização       → webhook charge.canceled
//   POST /transfers               → Pix ao profissional                    → webhook transfer.paid
declare(strict_types=1);

const CONTRATO_VERSAO = 'pagarme-core-v5@2026-06-04'; // ADR-016 h / integration-architecture §mock

// Estado mínimo entre requests (charge_id → external_reference/amount), em arquivo com flock.
// Necessário porque o webhook de capture/cancel precisa do external_reference que só passou
// no /orders — sem isso o ProcessarWebhookPagarmeJob não emite o evento de domínio (turnoId null).
const CHARGES_ARQUIVO = '/tmp/pagarme-mock-charges.json';

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$body = json_decode(file_get_contents('php://input') ?: '{}', true) ?: [];

error_log(sprintf('[MOCK] %s %s contrato=%s', $method, $path, CONTRATO_VERSAO));

header('Content-Type: application/json');

// Health check (STORY-006) preservado; /health para o liveness probe do Cloud Run
// (fake deployado em homolog — PDR-017 / ADR-016 d).
if ($method === 'GET' && ($path === '/' || $path === '/health')) {
    responder(200, ['mock' => true, 'provider' => 'pagarme', 'status' => 'up', 'contrato' => CONTRATO_VERSAO]);
}

// Autenticação Bearer (contract.md §auth): igual ao provedor real. Em homolog o fake é
// público (Cloud Run allUsers) — o Bearer impede POST anônimo disparando webhooks
// assinados contra o api (poluição). Local: default sk_mock, mesmo do apps/api/.env.
$secretKey = getenv('PAGARME_SECRET_KEY') ?: 'sk_mock';
$authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
if (! hash_equals('Bearer '.$secretKey, $authHeader)) {
    responder(401, ['mock' => true, 'erro' => 'credencial inválida (Authorization: Bearer esperado)']);
}

// POST /orders — pré-autorização (capture=false).
if ($method === 'POST' && $path === '/orders') {
    $orderId = 'or_'.bin2hex(random_bytes(8));
    $chargeId = 'ch_'.bin2hex(random_bytes(8));
    $externalRef = (string) ($body['external_reference'] ?? '');

    // O provedor real é stateful: capture/cancel não recebem external_reference no body,
    // mas o webhook deles o carrega (contract.md §webhook). O fake guarda o mínimo p/ ecoar.
    chargeGravar($chargeId, ['external_reference' => $externalRef, 'amount' => $body['amount'] ?? null]);

    emitirWebhook('charge.pending', $externalRef, ['charge_id' => $chargeId, 'order_id' => $orderId, 'amount' => $body['amount'] ?? null]);

    responder(200, [
        'id' => $orderId,
        'status' => 'pending',
        'external_reference' => $externalRef,
        'charges' => [['id' => $chargeId, 'status' => 'authorized', 'amount' => $body['amount'] ?? null]],
    ]);
}

// POST /charges/{id}/capture — captura total (amount da charge) ou parcial (amount do body).
if ($method === 'POST' && preg_match('#^/charges/([^/]+)/capture$#', $path, $m)) {
    $chargeId = $m[1];
    $charge = chargeLer($chargeId);
    $amount = $body['amount'] ?? $charge['amount'] ?? null;

    emitirWebhook('charge.paid', $charge['external_reference'] ?? null, ['charge_id' => $chargeId, 'amount' => $amount]);

    responder(200, ['id' => $chargeId, 'status' => 'paid', 'amount' => $amount]);
}

// POST /charges/{id}/cancel — libera/estorna a pré-autorização.
if ($method === 'POST' && preg_match('#^/charges/([^/]+)/cancel$#', $path, $m)) {
    $chargeId = $m[1];
    $charge = chargeLer($chargeId);

    emitirWebhook('charge.canceled', $charge['external_reference'] ?? null, ['charge_id' => $chargeId]);

    responder(200, ['id' => $chargeId, 'status' => 'canceled']);
}

// POST /transfers — Pix ao profissional. A chave Pix chega no body mas NÃO é ecoada no webhook.
//
// STORY-065 (CA-5, CA-7) — dois knobs de configuração:
//  - PAGARME_MOCK_PIX_RESULTADO = sucesso (default) | falha → `falha` emite
//    `transfer.failed` com razão Pagar.me-compatível (reason+message), tornando o caminho
//    de falha DETERMINÍSTICO em homolog (PDR-010: alerta na fila do admin);
//  - PAGARME_MOCK_PIX_SLA_SEGUNDOS (default 0) → atraso do webhook do Pix, simulando a
//    promessa pública "Pix em ≤ 15 min" (PDR-017: ~30s em homolog). A resposta HTTP sai
//    ANTES do atraso (o adapter não espera) — a conexão é fechada e o worker do PHP segue
//    para emitir; em Cloud Run isso exige CPU always-allocated (cpu_idle=false na infra).
if ($method === 'POST' && $path === '/transfers') {
    $transferId = 'tr_'.bin2hex(random_bytes(8));
    $externalRef = (string) ($body['external_reference'] ?? '');
    $amount = $body['amount'] ?? null;

    $pixFalha = getenv('PAGARME_MOCK_PIX_RESULTADO') === 'falha';
    $slaSegundos = max(0, (int) (getenv('PAGARME_MOCK_PIX_SLA_SEGUNDOS') ?: 0));

    $webhook = $pixFalha
        ? fn () => emitirWebhook('transfer.failed', $externalRef, [
            'transfer_id' => $transferId,
            'amount' => $amount,
            'reason' => 'invalid_pix_key',
            'message' => 'chave não encontrada na instituição de destino (cenário forçado — PAGARME_MOCK_PIX_RESULTADO=falha)',
        ])
        : fn () => emitirWebhook('transfer.paid', $externalRef, ['transfer_id' => $transferId, 'amount' => $amount]);

    // Resposta síncrona: `processing` espelha o provedor real (a confirmação É o webhook —
    // CA-6 fonte de verdade). Sucesso aparente também no cenário de falha: é exatamente o
    // caso "webhook reporta falha após sucesso aparente" que a estória manda cobrir.
    responder(200, ['id' => $transferId, 'status' => 'processing', 'external_reference' => $externalRef],
        aposResposta: function () use ($webhook, $slaSegundos) {
            if ($slaSegundos > 0) {
                sleep($slaSegundos);
            }
            $webhook();
        });
}

responder(404, ['mock' => true, 'erro' => 'rota não simulada', 'path' => $path]);

// ─────────────────────────────────────────────────────────────────────────────

/**
 * Responde e encerra. Com `$aposResposta`, FECHA a conexão primeiro (Content-Length +
 * Connection: close + flush) e só então executa o trabalho atrasado — o chamador (adapter
 * da ACL) nunca espera o SLA do webhook. Um worker do `php -S` fica ocupado durante o
 * sleep; PHP_CLI_SERVER_WORKERS cobre o paralelismo (mesmo padrão do `api`).
 */
function responder(int $status, array $payload, ?callable $aposResposta = null): never
{
    $corpo = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

    if ($aposResposta === null) {
        http_response_code($status);
        echo $corpo;
        exit;
    }

    ignore_user_abort(true);
    http_response_code($status);
    header('Content-Length: '.strlen($corpo));
    header('Connection: close');
    echo $corpo;
    if (ob_get_level() > 0) {
        ob_end_flush();
    }
    flush();

    $aposResposta();
    exit;
}

function chargeGravar(string $chargeId, array $dados): void
{
    $fp = fopen(CHARGES_ARQUIVO, 'c+');
    flock($fp, LOCK_EX);
    $tudo = json_decode(stream_get_contents($fp) ?: '{}', true) ?: [];
    $tudo[$chargeId] = $dados;
    ftruncate($fp, 0);
    rewind($fp);
    fwrite($fp, json_encode($tudo));
    flock($fp, LOCK_UN);
    fclose($fp);
}

function chargeLer(string $chargeId): array
{
    if (! is_file(CHARGES_ARQUIVO)) {
        return [];
    }
    $tudo = json_decode(file_get_contents(CHARGES_ARQUIVO) ?: '{}', true) ?: [];

    return $tudo[$chargeId] ?? [];
}

/**
 * Devolve o webhook assinado ao `api` (ADR-016 e). event_id único + HMAC do corpo no header
 * X-Pagarme-Signature. Fire-and-forget com timeout curto: o `api` responde 200 rápido e
 * processa no worker, então o mock não espera o processamento.
 */
function emitirWebhook(string $type, ?string $externalRef, array $data): void
{
    $alvo = getenv('PAGARME_WEBHOOK_TARGET') ?: 'http://api:8000/api/webhooks/pagarme';
    $secret = getenv('PAGARME_WEBHOOK_SECRET') ?: 'whsec_mock';

    $payload = [
        'id' => 'evt_'.bin2hex(random_bytes(8)),
        'type' => $type,
        'created_at' => gmdate('c'),
        'data' => array_merge($data, $externalRef !== null && $externalRef !== '' ? ['external_reference' => $externalRef] : []),
    ];
    $raw = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    $assinatura = hash_hmac('sha256', $raw, $secret);

    $ctx = stream_context_create(['http' => [
        'method' => 'POST',
        'header' => "Content-Type: application/json\r\nX-Pagarme-Signature: {$assinatura}\r\n",
        'content' => $raw,
        'timeout' => 5,
        'ignore_errors' => true,
    ]]);

    @file_get_contents($alvo, false, $ctx);
    error_log("[MOCK] webhook {$type} -> {$alvo}");
}
