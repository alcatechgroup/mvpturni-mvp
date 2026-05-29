<?php

// STORY-017 — Tabela auxiliar de funções pretendidas pelo profissional (IDR-006).
// Decisão do agente: tabela pequena com seed em vez de enum hard-coded, antecipando
// uso por STORY-019 (fila) e filtros de busca futuros. Reversível com drop table.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('funcoes', function (Blueprint $table) {
            $table->id();
            $table->string('slug', 60)->unique();
            $table->string('nome', 80);
            $table->boolean('ativo')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('funcoes');
    }
};
