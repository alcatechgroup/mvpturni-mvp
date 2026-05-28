<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/**
 * ADR-008: loga uma linha JSON por requisição com campos canônicos e
 * propaga X-Request-Id no response para rastreabilidade end-to-end.
 */
class RequestLogMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $startedAt = microtime(true);

        // Reusa o trace do Cloud Run se disponível; fallback = UUID v4.
        // X-Cloud-Trace-Context: <TRACE_ID>/<SPAN_ID>;o=TRACE_TRUE
        $traceHeader = $request->header('X-Cloud-Trace-Context');
        $requestId = $traceHeader
            ? explode('/', $traceHeader)[0]
            : (string) Str::uuid();

        $response = $next($request);

        $durationMs = (int) round((microtime(true) - $startedAt) * 1000);

        Log::info('request.handled', [
            'service' => 'backoffice',
            'env' => config('app.env'),
            'version' => env('APP_VERSION', 'unknown'),
            'request_id' => $requestId,
            'method' => $request->method(),
            'path' => $request->path(),
            'status_code' => $response->getStatusCode(),
            'duration_ms' => $durationMs,
        ]);

        $response->headers->set('X-Request-Id', $requestId);

        return $response;
    }
}
