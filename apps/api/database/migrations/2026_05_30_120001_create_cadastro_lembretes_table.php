<?php

// STORY-021 — CA-5 — Tabela auxiliar de lembretes de completar cadastro. Idempotente
// por (user_id, numero): cada um dos 3 lembretes (48h/5d/14d) é registrado uma única
// vez, o que evita reenvio mesmo se o scheduler rodar mais de uma vez no dia. Reversível.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('cadastro_lembretes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->unsignedTinyInteger('numero'); // 1=48h, 2=5d, 3=14d
            $table->timestampTz('enviado_em');
            $table->timestamps();

            // Idempotência: no máximo um registro por número de lembrete por usuário.
            $table->unique(['user_id', 'numero']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('cadastro_lembretes');
    }
};
