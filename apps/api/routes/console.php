<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Lembrete de completar cadastro (STORY-021 CA-5): 1×/dia às 09:00 BRT.
// withoutOverlapping evita sobreposição se uma execução demorar; onOneServer é
// inócuo no MVP (1 worker) mas correto se escalar.
Schedule::command('lembretes:cadastro')
    ->dailyAt('09:00')
    ->timezone('America/Sao_Paulo')
    ->withoutOverlapping();

// Auto-retirada de candidaturas não confirmadas após edição material (STORY-052 CA-9 / PDR-009).
// 1×/min para honrar o "24h ou início do turno" com granularidade fina; reusa o Cloud Run Job
// + Scheduler da STORY-034. Idempotente, então withoutOverlapping é só higiene.
Schedule::command('candidaturas:auto-retirar-apos-edicao')
    ->everyMinute()
    ->withoutOverlapping();

// E-mail das notificações (STORY-053 CA-5): drena a fila implícita `notificacoes`. 1×/min para o
// SLA de ≤60s p95 (CA-9); reusa o Cloud Run Job + Scheduler da STORY-034. Retry/backoff via
// `tentativas_envio` na própria tabela; withoutOverlapping evita lote concorrente.
Schedule::command('notificacoes:enviar-emails')
    ->everyMinute()
    ->withoutOverlapping();
