<?php

// STORY-016 — CA-1 — Perfil específico do contratante (ADR-009 Decisão 1C).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('contratante_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('cnpj_encrypted')->nullable(); // Eloquent Encrypted Cast
            $table->string('nome_estabelecimento')->nullable();
            $table->string('tipo_operacao')->nullable();
            $table->text('endereco_completo')->nullable();
            $table->string('plano', 30)->nullable(); // member_start|member|enterprise
            $table->string('logo_path')->nullable();
            $table->timestamps();

            $table->unique('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('contratante_profiles');
    }
};
