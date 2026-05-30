<?php

// STORY-021 — CA-5 — Réplica (para o banco de teste do admin) do carimbo de aprovação
// `aprovado_em`. O schema real do `turni` é de responsabilidade do app `api` (ADR-002);
// o admin replica as colunas que escreve/lê para rodar a própria suíte. O ApprovalService
// preenche `aprovado_em` na transição pendente_aprovacao → liberado.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestampTz('aprovado_em')->nullable()->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('aprovado_em');
        });
    }
};
