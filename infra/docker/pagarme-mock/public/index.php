<?php
// Stub do mock Pagar.me (ADR-005). Responde 200 em qualquer rota com um marcador
// [MOCK] — suficiente para STORY-006 (serviço de pé). Endpoints reais de
// pré-autorização/captura/Pix/webhook serão implementados no EPIC-003.
declare(strict_types=1);

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

// Log [MOCK] em stderr (error_log) — paridade com a convenção do ADR-005.
error_log(sprintf('[MOCK] %s %s', $_SERVER['REQUEST_METHOD'] ?? 'GET', $path));

header('Content-Type: application/json');
http_response_code(200);
echo json_encode([
    'mock' => true,
    'provider' => 'pagarme',
    'status' => 'up',
    'note' => 'STORY-006: mock de pé, sem rotas funcionais (EPIC-003 implementa)',
    'path' => $path,
], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
