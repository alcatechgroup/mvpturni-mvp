<?php

// STORY-016 — CA-1 — Perfil específico do profissional (ADR-009 Decisão 1C).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('profissional_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('tipo_pessoa', 10); // PF | MEI | PJ
            $table->text('documento_encrypted')->nullable(); // CPF ou CNPJ — Eloquent Encrypted Cast
            $table->string('documento_tipo', 10)->nullable(); // CPF | CNPJ
            $table->string('nivel', 20)->nullable(); // Iniciante|Confiavel|Destaque|Elite
            $table->decimal('score', 5, 2)->default(0);
            $table->unsignedInteger('xp')->default(0);
            $table->unsignedInteger('turnos_realizados')->default(0);
            $table->text('bio')->nullable();
            $table->text('chave_pix_encrypted')->nullable(); // Eloquent Encrypted Cast
            $table->jsonb('dados_bancarios_encrypted')->nullable(); // Eloquent Encrypted Cast
            $table->string('foto_path')->nullable();
            $table->timestamps();

            $table->unique('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('profissional_profiles');
    }
};
