<?php

// STORY-020 / ADR-010 — Catálogo de templates contratuais (`templates`) e versionamento
// append-only (`template_versoes`). Invariantes garantidas no banco (PostgreSQL):
//   - partial unique index: no máximo UMA versão ativa por template (Decisão 2A);
//   - trigger BEFORE UPDATE: conteúdo/versão/template_id/autor imutáveis após criação —
//     toda edição é nova versão (Decisão 2 / PDR-012);
//   - REVOKE DELETE no role de runtime (append-only — coerente com ADR-009).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('templates', function (Blueprint $table) {
            $table->id();
            $table->string('slug', 50)->unique();
            $table->string('nome_amigavel', 200);
            $table->timestampsTz();
        });

        Schema::create('template_versoes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('template_id')->constrained('templates');
            $table->integer('versao');
            $table->text('conteudo');
            $table->foreignId('criado_por_admin_id')->constrained('users');
            $table->boolean('ativa')->default(false);
            // Append-only: sem updated_at. Só `ativa` muda após o INSERT (ativação/desativação).
            $table->timestampTz('created_at')->default(DB::raw('NOW()'));

            $table->unique(['template_id', 'versao'], 'template_versoes_unique_versao');
        });

        // versao > 0 (ADR-010 Decisão 2).
        DB::statement('ALTER TABLE template_versoes ADD CONSTRAINT template_versoes_versao_positiva CHECK (versao > 0)');

        // No máximo uma versão ativa por template — enforço mecânico (Decisão 2A).
        DB::statement('CREATE UNIQUE INDEX template_versoes_active_per_template ON template_versoes (template_id) WHERE ativa = TRUE');

        // Imutabilidade do conteúdo: só `ativa` pode mudar via UPDATE (Decisão 2 / PDR-012, CA-10).
        DB::unprepared('
            CREATE OR REPLACE FUNCTION prevent_template_versao_content_mutation()
            RETURNS TRIGGER LANGUAGE plpgsql AS $$
            BEGIN
                IF NEW.conteudo IS DISTINCT FROM OLD.conteudo THEN
                    RAISE EXCEPTION \'template_versoes.conteudo é imutável após criação — crie uma nova versão\';
                END IF;
                IF NEW.template_id IS DISTINCT FROM OLD.template_id THEN
                    RAISE EXCEPTION \'template_versoes.template_id é imutável após criação\';
                END IF;
                IF NEW.versao IS DISTINCT FROM OLD.versao THEN
                    RAISE EXCEPTION \'template_versoes.versao é imutável após criação\';
                END IF;
                IF NEW.criado_por_admin_id IS DISTINCT FROM OLD.criado_por_admin_id THEN
                    RAISE EXCEPTION \'template_versoes.criado_por_admin_id é imutável após criação\';
                END IF;
                RETURN NEW;
            END;
            $$;
        ');

        DB::unprepared('
            CREATE TRIGGER prevent_template_versao_content_mutation
            BEFORE UPDATE ON template_versoes
            FOR EACH ROW EXECUTE FUNCTION prevent_template_versao_content_mutation();
        ');

        // Append-only: o runtime nunca apaga uma versão (defesa em profundidade, padrão ADR-009).
        // UPDATE permanece permitido — a ativação precisa alterar a coluna `ativa`.
        $runtimeUser = config('database.connections.pgsql.username', 'turni');
        DB::unprepared("REVOKE DELETE ON template_versoes FROM \"{$runtimeUser}\"");
    }

    public function down(): void
    {
        $runtimeUser = config('database.connections.pgsql.username', 'turni');
        // GRANT defensivo: sem ele, o DROP a seguir pode falhar se o role não puder mais tocar a tabela.
        DB::unprepared("GRANT DELETE ON template_versoes TO \"{$runtimeUser}\"");
        DB::unprepared('DROP TRIGGER IF EXISTS prevent_template_versao_content_mutation ON template_versoes');
        DB::unprepared('DROP FUNCTION IF EXISTS prevent_template_versao_content_mutation()');
        Schema::dropIfExists('template_versoes');
        Schema::dropIfExists('templates');
    }
};
