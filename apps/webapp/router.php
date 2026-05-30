<?php

/**
 * Router do servidor de desenvolvimento do WebApp (php -S).
 *
 * Espelha, em dev local, a topologia same-origin de produção: no Firebase Hosting,
 * `/api/**` e `/sanctum/**` são reescritos para o Cloud Run da API (firebase.json).
 * Aqui, o mesmo origin `localhost:<WEBAPP_PORT>` serve o build Flutter e encaminha
 * essas rotas para o container `api`. Same-origin é o que faz o cookie de sessão do
 * Sanctum (SameSite=lax) trafegar — sem isso, chamadas autenticadas (ex.: STORY-022
 * /api/usuarios/me/welcome-visto) não recebem a sessão. Não é código de produção:
 * em produção quem faz o rewrite é o Firebase.
 *
 * Demais requisições retornam `false` → o php -S serve o arquivo estático normalmente
 * (com fallback de SPA já existente).
 */

// Deprecations não podem virar saída antes dos headers (quebraria o relay de Set-Cookie).
error_reporting(E_ALL & ~E_DEPRECATED);

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/';

$isApi = str_starts_with($uri, '/api') || str_starts_with($uri, '/sanctum');
if (! $isApi) {
    return false; // serve estático
}

$target = 'http://api:8000'.$_SERVER['REQUEST_URI'];

$contentType = $_SERVER['CONTENT_TYPE'] ?? '';
$isMultipart = stripos($contentType, 'multipart/form-data') === 0;

// Cabeçalhos de entrada relevantes para repassar à API (inclui Cookie e CSRF).
// Para multipart, deixamos o cURL reconstruir o Content-Type (com novo boundary) —
// o boundary original não vale para o corpo que reconstruímos a partir de $_POST/$_FILES.
// Headers que o cURL recalcula a partir do corpo — não repassar os originais (o corpo
// pode ser remontado, mudando tamanho/boundary).
$skip = ['Host', 'Content-Length', 'Content-Type', 'Expect', 'Transfer-Encoding', 'Connection'];
$forwardHeaders = [];
foreach ($_SERVER as $key => $value) {
    if (str_starts_with($key, 'HTTP_')) {
        $name = str_replace(' ', '-', ucwords(strtolower(str_replace('_', ' ', substr($key, 5)))));
        if (in_array($name, $skip, true)) {
            continue;
        }
        $forwardHeaders[] = "$name: $value";
    }
}
// Evita Expect: 100-continue do cURL em uploads (alguns servidores tratam mal).
$forwardHeaders[] = 'Expect:';
if (! $isMultipart && $contentType !== '') {
    $forwardHeaders[] = 'Content-Type: '.$contentType;
}

$ch = curl_init($target);
curl_setopt_array($ch, [
    CURLOPT_CUSTOMREQUEST => $_SERVER['REQUEST_METHOD'],
    CURLOPT_HTTPHEADER => $forwardHeaders,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HEADER => true,
    CURLOPT_FOLLOWLOCATION => false,
]);

if (! in_array($_SERVER['REQUEST_METHOD'], ['GET', 'HEAD'], true)) {
    if ($isMultipart) {
        // multipart/form-data: o PHP já consumiu php://input e populou $_POST/$_FILES,
        // deixando php://input vazio. Reconstruímos os campos + arquivos como array para
        // o cURL remontar o corpo multipart (com boundary próprio).
        $fields = $_POST;
        foreach ($_FILES as $field => $file) {
            if (is_uploaded_file($file['tmp_name']) || is_file($file['tmp_name'])) {
                $fields[$field] = new CURLFile($file['tmp_name'], $file['type'], $file['name']);
            }
        }
        curl_setopt($ch, CURLOPT_POSTFIELDS, $fields);
    } else {
        curl_setopt($ch, CURLOPT_POSTFIELDS, file_get_contents('php://input'));
    }
}

$response = curl_exec($ch);
if ($response === false) {
    $error = curl_error($ch);
    http_response_code(502);
    header('Content-Type: application/json');
    echo json_encode(['message' => 'Proxy dev falhou ao alcançar a API.', 'error' => $error]);

    return true;
}

$headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
$status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$rawHeaders = substr($response, 0, $headerSize);
$body = substr($response, $headerSize);

http_response_code($status);
foreach (explode("\r\n", $rawHeaders) as $line) {
    if ($line === '' || stripos($line, 'HTTP/') === 0) {
        continue;
    }
    // Pula cabeçalhos hop-by-hop / de comprimento que o php -S recalcula.
    if (preg_match('/^(Transfer-Encoding|Connection|Content-Length):/i', $line)) {
        continue;
    }
    // Set-Cookie pode repetir — não sobrescreve (false no 2º arg).
    header($line, stripos($line, 'Set-Cookie:') !== 0);
}

echo $body;

return true;
