<?php

// STORY-096 — RÉPLICAS DE TESTE de `turnos` e `audit_logs` (as migrações CANÔNICAS vivem no
// app `api`, dono do banco `turni` real; o admin replica só o que os testes da fila de disputa
// precisam — mesma disciplina das réplicas de pix_falhas / profissional / contratante_profiles).
//
// Divergências DELIBERADAS da canônica (o admin só LÊ estas tabelas — ADR-020 Decisão 6):
//  - `turnos.status` é string simples: a canônica usa enum nativo `turno_status` + trigger
//    `enforce_turno_transition` (invariante de banco, ADR-015). A máquina de estados é garantida
//    NA API; o admin nunca transita o turno (resolução = comando da api via IDR-032), então a
//    réplica não precisa do enum/trigger.
//  - sem a cadeia vagas/candidaturas/vaga_versoes: a fila/caso compõem o que já está no turno +
//    audit_logs + perfis (função via ProfissionalProfile.funcao_id), sem JOIN naquela cadeia.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('turnos', function (Blueprint $table) {
            $table->uuid('id')->primary();

            // Partes do turno (a fila mostra estabelecimento ⇄ profissional).
            $table->foreignUuid('contratante_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('profissional_id')->constrained('users')->cascadeOnDelete();

            // Estado do turno: string na réplica (enum nativo + trigger na canônica/ADR-015).
            $table->string('status', 40);

            // Financeiro congelado no aceite (o que o profissional recebe — exibido na fila/caso).
            $table->decimal('valor', 10, 2);

            // Janela do turno (vaga original congelada) + cronômetro (check-in/out validados).
            $table->timestampTz('data_inicio')->nullable();
            $table->timestampTz('data_fim')->nullable();
            $table->timestampTz('check_in_at')->nullable();
            $table->timestampTz('check_out_at')->nullable();

            // Geofencing alerta-e-registra (PDR-008) e disputa (ADR-020 Decisão 1).
            $table->jsonb('geofencing_check_in')->nullable();
            $table->jsonb('geofencing_check_out')->nullable();
            $table->jsonb('disputa')->nullable();

            // Snapshot da vaga vigente no aceite (apenas referência; sem FK na réplica).
            $table->uuid('vaga_versao_id')->nullable();

            $table->timestampsTz();

            // Fila derivada do estado (ADR-020 Decisão 4): consulta por status.
            $table->index('status');
        });

        Schema::create('audit_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('action', 100);
            $table->string('target_type', 100)->nullable();
            $table->uuid('target_id')->nullable();
            $table->jsonb('payload')->nullable();
            $table->ipAddress('ip')->nullable();
            $table->text('user_agent')->nullable();
            // Append-only na canônica (trigger + REVOKE); a réplica só lê — só created_at.
            $table->timestampTz('created_at')->default(DB::raw('NOW()'));

            $table->index(['target_type', 'target_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('turnos');
    }
};
