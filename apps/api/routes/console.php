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
