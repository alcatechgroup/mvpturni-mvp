<?php

// STORY-018 — Campos mínimos do pré-cadastro de contratante (domain/usuario.md §Contratante).
// nome_estabelecimento e tipo_operacao já existem (criados na STORY-016). Aqui somam-se
// telefone (do responsável), cidade (localização mínima — não é o endereço completo, que
// vem na STORY-024), foto_path (avatar do responsável) e termos_aceitos_at (consentimento
// LGPD). Colunas nullable no banco; obrigatoriedade no pré-cadastro é garantida no
// FormRequest. Reversível com dropColumn (espelha a migração da STORY-017).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('contratante_profiles', function (Blueprint $table) {
            $table->string('telefone', 20)->nullable()->after('tipo_operacao');
            $table->string('cidade', 120)->nullable()->after('telefone');
            $table->string('foto_path')->nullable()->after('logo_path');
            // Timestamp do aceite dos Termos/Política — consentimento explícito (LGPD).
            $table->timestampTz('termos_aceitos_at')->nullable()->after('foto_path');
        });
    }

    public function down(): void
    {
        Schema::table('contratante_profiles', function (Blueprint $table) {
            $table->dropColumn(['telefone', 'cidade', 'foto_path', 'termos_aceitos_at']);
        });
    }
};
