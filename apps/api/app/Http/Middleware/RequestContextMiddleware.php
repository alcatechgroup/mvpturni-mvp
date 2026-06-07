<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Context;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/**
 * ADR-008 §f (STORY-068 F-NB-2) — correlação `request_id` api→fila→worker.
 *
 * Lê o header de correlação entrante — preferindo o X-Cloud-Trace-Context que o
 * Cloud Run injeta (reaproveita o trace do GCP), com fallback ULID — e o coloca no
 * Context do Laravel: (a) toda linha de log da requisição ganha `extra.request_id`
 * no JSON (inclui os eventos financeiros do PagamentoEvents); (b) o contexto é
 * desidratado no payload de jobs enfileirados e re-hidratado no worker, então a
 * cadeia pré-autorização → captura → Pix loga o MESMO request_id (ADR-016 g).
 * O X-Request-Id volta no response para casar relatos do WebApp com o servidor
 * (espelho do RequestLogMiddleware do admin — sem a linha request.handled aqui:
 * o access log JSON do nginx já loga cada requisição do api).
 */
class RequestContextMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        // X-Cloud-Trace-Context: <TRACE_ID>/<SPAN_ID>;o=TRACE_TRUE
        $traceHeader = $request->header('X-Cloud-Trace-Context');
        $requestId = $traceHeader
            ? explode('/', $traceHeader)[0]
            : (string) Str::ulid();

        Context::add('request_id', $requestId);

        $response = $next($request);

        $response->headers->set('X-Request-Id', $requestId);

        return $response;
    }
}
