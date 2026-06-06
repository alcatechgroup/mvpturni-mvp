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

// Sweeper/backfill do e-mail das notificações (STORY-053 CA-5). REDE DE SEGURANÇA, não o caminho
// primário: a entrega real é EnviarEmailDaNotificacaoJob na fila `database`, processada pelo
// `queue:work` (Cloud Run Job dedicado — por isso a fila, não o Schedule). Desde a STORY-073 o
// `schedule:run` roda em homolog/prod (Cloud Run Job `turni-scheduler-job-<env>` + Cloud
// Scheduler 1/min), então este sweeper reprocessa pendências (ex.: jobs perdidos) de verdade.
Schedule::command('notificacoes:enviar-emails')
    ->everyMinute()
    ->withoutOverlapping();

// Detecção de no-show (STORY-066 CA-5): turnos `confirmado`/`aguardando_checkin` sem
// check-in até X horas após o início previsto (X = config turno.no_show_horas — 2h,
// decisão do PO 2026-06-06) viram `no_show_pro` e liberam a pré-autorização. everyMinute;
// idempotente (`no_show_pro` é terminal), withoutOverlapping é higiene. Dispara via
// `schedule:run` plumbado em homolog/prod pela STORY-073.
Schedule::command('turnos:detectar-no-show')
    ->everyMinute()
    ->withoutOverlapping();
