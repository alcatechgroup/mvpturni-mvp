#!/usr/bin/env node
// @ts-nocheck
/**
 * Proxy reverso same-origin para o harness de integration_test do WebApp no Web
 * (STORY-043 / IDR-021). Node puro, sem dependências.
 *
 * Por que existe: sob `flutter drive -d web-server`, o app é servido numa porta
 * (APP_PORT) DIFERENTE da API (API_PORT) — origem cruzada. O cookie de sessão do
 * Sanctum (SameSite=Lax) NÃO trafega cross-origin, então chamadas autenticadas
 * pós-login (ex.: POST /api/usuarios/me/welcome-visto) falham no browser do teste.
 *
 * Este proxy expõe app + API numa ÚNICA origem (PROXY_PORT, default :3000):
 *   - /api/*  e /sanctum/*  → API real    (localhost:API_PORT)
 *   - todo o resto          → dev-server do flutter drive (localhost:APP_PORT)
 * Com o browser apontado ao proxy (via `--web-launch-url=http://localhost:3000`),
 * app e API são same-origin → o cookie Sanctum é guardado e reenviado sozinho,
 * exatamente como em produção (Firebase reescreve /api e /sanctum — IDR-014).
 * `localhost:3000` já é stateful no Sanctum (config/sanctum.php default), então
 * NADA de produção muda: sem CORS, sem withCredentials, sem mock.
 *
 * Espelha o router.php de dev (mesma topologia), mas no host e em node, porque o
 * dev-server do flutter drive roda no host (não no container webapp).
 *
 * Uso: node scripts/e2e-webapp-proxy.js
 *   PROXY_PORT (3000)  porta que o browser abre (deve ser stateful no Sanctum)
 *   APP_PORT   (7357)  dev-server do flutter drive (--web-port)
 *   API_PORT   (8001)  API real (docker-compose)
 */
'use strict';

const http = require('http');
const net = require('net');

const PROXY_PORT = Number(process.env.PROXY_PORT || 3000);
const APP_PORT = Number(process.env.APP_PORT || 7357);
const API_PORT = Number(process.env.API_PORT || 8001);
const HOST = '127.0.0.1';

/** Decide o alvo (API vs dev-server) pela rota — mesma regra do router.php. */
function targetPortFor(url) {
  return url.startsWith('/api') || url.startsWith('/sanctum') ? API_PORT : APP_PORT;
}

const server = http.createServer((clientReq, clientRes) => {
  const port = targetPortFor(clientReq.url);
  if (process.env.E2E_PROXY_DEBUG) {
    process.stderr.write(`[req] ${clientReq.method} ${clientReq.url} → :${port}\n`);
  }

  // Repassa os headers como vieram (inclui Cookie e X-XSRF-TOKEN); só reescreve o
  // Host para o alvo. Same-origin → o browser já manda os cookies certos.
  const headers = { ...clientReq.headers, host: `${HOST}:${port}` };

  const proxyReq = http.request(
    { host: HOST, port, method: clientReq.method, path: clientReq.url, headers },
    (proxyRes) => {
      // Relay do status + headers preservando Set-Cookie como array (múltiplos cookies).
      clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(clientRes);
    },
  );

  proxyReq.on('error', (err) => {
    clientRes.writeHead(502, { 'content-type': 'application/json' });
    clientRes.end(JSON.stringify({ message: 'proxy e2e falhou', error: String(err) }));
  });

  clientReq.pipe(proxyReq);
});

// WebSocket / HTTP upgrade (dwds hot-restart channel do flutter drive) → dev-server.
server.on('upgrade', (req, socket, head) => {
  const port = targetPortFor(req.url);
  const upstream = net.connect(port, HOST, () => {
    const headerLines = [`${req.method} ${req.url} HTTP/1.1`];
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      headerLines.push(`${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}`);
    }
    upstream.write(headerLines.join('\r\n') + '\r\n\r\n');
    if (head && head.length) upstream.write(head);
    socket.pipe(upstream);
    upstream.pipe(socket);
  });
  const drop = () => {
    socket.destroy();
    upstream.destroy();
  };
  upstream.on('error', drop);
  socket.on('error', drop);
});

server.listen(PROXY_PORT, HOST, () => {
  process.stdout.write(
    `[e2e-proxy] :${PROXY_PORT} → app :${APP_PORT} / api+sanctum :${API_PORT}\n`,
  );
});
