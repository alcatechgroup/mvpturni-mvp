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

// Health check (STORY-006) preservado.
if ($method === 'GET' && $path === '/') {
    responder(200, ['mock' => true, 'provider' => 'pagarme', 'status' => 'up', 'contrato' => CONTRATO_VERSAO]);
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
if ($method === 'POST' && $path === '/transfers') {
    $transferId = 'tr_'.bin2hex(random_bytes(8));
    $externalRef = (string) ($body['external_reference'] ?? '');

    emitirWebhook('transfer.paid', $externalRef, ['transfer_id' => $transferId, 'amount' => $body['amount'] ?? null]);

    responder(200, ['id' => $transferId, 'status' => 'paid', 'external_reference' => $externalRef]);
}

responder(404, ['mock' => true, 'erro' => 'rota não simulada', 'path' => $path]);

// ─────────────────────────────────────────────────────────────────────────────

function responder(int $status, array $payload): never
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
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
