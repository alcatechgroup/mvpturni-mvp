<?php

// STORY-017 — Campos mínimos do pré-cadastro de profissional (domain/usuario.md).
// Colunas nullable no banco (linhas pré-existentes / criação em duas etapas no futuro);
// obrigatoriedade no pré-cadastro é garantida no FormRequest. Reversível com dropColumn.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('profissional_profiles', function (Blueprint $table) {
            $table->string('telefone', 20)->nullable()->after('tipo_pessoa');
            $table->string('cidade', 120)->nullable()->after('telefone');
            $table->string('bairro', 120)->nullable()->after('cidade');
            $table->foreignId('funcao_id')->nullable()->after('bairro')
                ->constrained('funcoes')->nullOnDelete();
            // Timestamp do aceite dos Termos/Política — consentimento explícito (LGPD).
            $table->timestampTz('termos_aceitos_at')->nullable()->after('foto_path');
        });
    }

    public function down(): void
    {
        Schema::table('profissional_profiles', function (Blueprint $table) {
            $table->dropConstrainedForeignId('funcao_id');
            $table->dropColumn(['telefone', 'cidade', 'bairro', 'termos_aceitos_at']);
        });
    }
};
