<?php

// STORY-085 / ADR-019 Decisão 1 (CA-1) — agregado próprio `avaliacoes`: uma linha por
// direção/turno da avaliação recíproca (PDR-005). Diverge do esboço jsonb de turno.md de
// propósito (ADR-019): reputação consultável por construção (média + depoimentos viram
// queries sobre o índice de cobertura) e invariantes "uma por direção / estrelas 1–5
// obrigatórias / ninguém se autoavalia" como INVARIANTE DE BANCO, à prova de SQL cru.
//
// Também alinha o schema de reputação ao motor (ADR-019 Decisão 4):
//  - profissional_profiles.xp: unsignedInteger → integer (signed) — "XP pode ficar negativo
//    localmente sem rebaixar" (niveis-e-score.md);
//  - contratante_profiles ganha `score` decimal(5,2) — reciprocidade (contratante tem score,
//    sem nível/XP no MVP).
//
// down() simétrico: reverte score do contratante → reverte xp → drop table → drop type.

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Enum nativo da direção (ADR-019 Decisão 1) — o UNIQUE abaixo o usa para exprimir
        // "uma avaliação por direção por turno".
        DB::statement("CREATE TYPE avaliacao_direcao AS ENUM (
            'contratante_para_profissional',
            'profissional_para_contratante'
        )");

        Schema::create('avaliacoes', function (Blueprint $table) {
            $table->uuid('id')->primary();

            // restrictOnDelete: avaliação é histórico de reputação — não some com o turno/usuário.
            $table->foreignUuid('turno_id')->constrained('turnos')->restrictOnDelete();
            $table->foreignUuid('autor_id')->constrained('users')->restrictOnDelete();    // quem avaliou
            $table->foreignUuid('avaliado_id')->constrained('users')->restrictOnDelete();  // quem recebeu

            // `direcao` é adicionada via ALTER (enum nativo — Laravel não tem builder próprio).

            $table->smallInteger('estrelas');     // 1–5 obrigatória (CHECK + NOT NULL abaixo)
            $table->text('comentario')->nullable(); // depoimento quando não-vazio

            $table->timestampsTz();
        });

        DB::statement('ALTER TABLE avaliacoes ADD COLUMN direcao avaliacao_direcao NOT NULL');

        // ── Invariantes duras no banco (CA-1) ─────────────────────────────────────────────
        // Uma avaliação por direção por turno (fail-secure contra avaliação dupla via SQL cru).
        DB::statement('ALTER TABLE avaliacoes ADD CONSTRAINT avaliacoes_unica_por_direcao UNIQUE (turno_id, direcao)');
        // Estrelas obrigatórias 1–5 (PDR-005). NOT NULL já vem do smallInteger sem nullable().
        DB::statement('ALTER TABLE avaliacoes ADD CONSTRAINT avaliacoes_estrelas_faixa CHECK (estrelas BETWEEN 1 AND 5)');
        // Ninguém se autoavalia.
        DB::statement('ALTER TABLE avaliacoes ADD CONSTRAINT avaliacoes_autor_diferente_avaliado CHECK (autor_id <> avaliado_id)');

        // ── Índices (ADR-019 Decisão 1) ───────────────────────────────────────────────────
        // Cobertura única que serve a recomputação de score (média das recebidas) E a query de
        // depoimentos (N mais recentes recebidos por X) — ambas partem de avaliado_id.
        DB::statement('CREATE INDEX idx_avaliacoes_avaliado_recente ON avaliacoes (avaliado_id, created_at DESC)');
        // "Minhas avaliações dadas".
        DB::statement('CREATE INDEX idx_avaliacoes_autor ON avaliacoes (autor_id)');

        // ── Alinhamento do schema de reputação ao motor (ADR-019 Decisão 4) ───────────────
        // xp signed: a coluna unsignedInteger rejeitaria o negativo previsto pela spec.
        DB::statement('ALTER TABLE profissional_profiles ALTER COLUMN xp TYPE integer');
        DB::statement('ALTER TABLE profissional_profiles ALTER COLUMN xp SET DEFAULT 0');

        // Score do contratante (reciprocidade — niveis-e-score.md). Sem nível/XP no MVP.
        Schema::table('contratante_profiles', function (Blueprint $table) {
            $table->decimal('score', 5, 2)->default(0)->after('plano');
        });
    }

    public function down(): void
    {
        Schema::table('contratante_profiles', function (Blueprint $table) {
            $table->dropColumn('score');
        });

        // Reverte xp ao tipo original (unsignedInteger = int4 sem sinal no Laravel/Postgres
        // é apenas integer com CHECK >= 0; o builder original usou unsignedInteger). Para a
        // reversibilidade prática, voltamos a integer NOT NULL DEFAULT 0 — equivalente ao
        // estado consultável anterior (Postgres não tem unsigned nativo).
        DB::statement('ALTER TABLE profissional_profiles ALTER COLUMN xp TYPE integer');
        DB::statement('ALTER TABLE profissional_profiles ALTER COLUMN xp SET DEFAULT 0');

        Schema::dropIfExists('avaliacoes');
        DB::statement('DROP TYPE IF EXISTS avaliacao_direcao');
    }
};
