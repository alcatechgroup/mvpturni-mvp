<?php

// STORY-044 / ADR-013 (CA-3, CA-4, CA-5) — `candidaturas`.
//  - estado em enum NATIVO do Postgres (`candidatura_estado`);
//  - UNIQUE(vaga_id, profissional_id): não candidata 2x na mesma vaga (CA-5);
//  - vaga_versao_id: versão que o profissional viu/confirmou (PDR-009);
//  - índices para painel de candidatos e "minhas candidaturas"/conflito de horário.
// down() simétrico: drop table → drop type (F-NB-1).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("CREATE TYPE candidatura_estado AS ENUM (
            'pendente', 'aprovada', 'retirada',
            'pendente_revisao_apos_edicao', 'retirada_por_edicao', 'recusada'
        )");

        Schema::create('candidaturas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vaga_id')->constrained('vagas')->restrictOnDelete();
            $table->foreignId('profissional_id')->constrained('users')->restrictOnDelete();
            // `estado` adicionado via ALTER (enum nativo).
            $table->foreignId('vaga_versao_id')->nullable()->constrained('vaga_versoes')->nullOnDelete();
            $table->timestampTz('revisao_prazo_em')->nullable();
            $table->timestampTz('aprovada_em')->nullable();
            $table->timestampTz('retirada_em')->nullable();
            $table->timestampsTz();

            $table->unique(['vaga_id', 'profissional_id'], 'candidaturas_unique_vaga_profissional');
        });

        DB::statement("ALTER TABLE candidaturas ADD COLUMN estado candidatura_estado NOT NULL DEFAULT 'pendente'");

        // Painel de candidatos da vaga (STORY-051).
        DB::statement('CREATE INDEX idx_candidaturas_vaga ON candidaturas (vaga_id, estado)');
        // "Candidatadas" + consulta de conflito de horário/habitualidade (STORY-050).
        DB::statement('CREATE INDEX idx_candidaturas_profissional ON candidaturas (profissional_id, estado)');
    }

    public function down(): void
    {
        Schema::dropIfExists('candidaturas');
        DB::statement('DROP TYPE IF EXISTS candidatura_estado');
    }
};
