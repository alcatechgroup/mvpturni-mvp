<?php

// STORY-065 — RÉPLICA de teste da `pix_falhas` (a migração CANÔNICA vive no app `api`,
// dono do banco `turni` real; o admin replica só o que os testes dele precisam — mesma
// disciplina das réplicas de profissional/contratante_profiles).
//
// Diverge da canônica DE PROPÓSITO em um ponto: `turno_id` é uuid simples (sem FK),
// porque o admin não replica a cadeia turnos/vagas/candidaturas — a fila lê apenas o
// SNAPSHOT operacional desta tabela (decisão da STORY-065; IDR-028).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pix_falhas', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('turno_id')->unique(); // FK na canônica (api); réplica sem turnos

            // Snapshot operacional do instante da falha (o admin lê uma tabela só).
            $table->text('profissional_nome')->nullable();
            $table->text('funcao')->nullable();
            $table->text('estabelecimento')->nullable();
            $table->decimal('valor', 10, 2)->nullable();

            // Chave Pix cifrada com segredo compartilhado api+admin (IDR-028).
            $table->text('chave_pix')->nullable();

            $table->text('razao');
            $table->jsonb('payload_gateway')->nullable();
            $table->timestampTz('falhou_em');

            $table->timestampTz('resolvido_em')->nullable();
            $table->foreignUuid('resolvido_por')->nullable()->constrained('users')->nullOnDelete();
            $table->text('nota_resolucao')->nullable();

            $table->timestampsTz();

            $table->index(['resolvido_em', 'falhou_em']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pix_falhas');
    }
};
