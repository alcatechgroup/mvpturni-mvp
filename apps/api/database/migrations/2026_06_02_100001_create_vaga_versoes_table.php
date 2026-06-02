<?php

// STORY-044 / ADR-013 Decisão 1 (CA-1, CA-5) — `vaga_versoes`: snapshot append-only
// dos campos materiais (PDR-009). Imutabilidade no banco (trigger BEFORE UPDATE/DELETE
// + REVOKE no role de runtime) — mesmo padrão da AceiteEletronico/ADR-010.
// UNIQUE(vaga_id, versao). down() simétrico (F-NB-1).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('vaga_versoes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vaga_id')->constrained('vagas');
            $table->smallInteger('versao');
            $table->jsonb('snapshot');
            $table->foreignId('editado_por')->nullable()->constrained('users')->nullOnDelete();
            // Append-only: só created_at, com default no banco.
            $table->timestampTz('created_at')->default(DB::raw('NOW()'));

            $table->unique(['vaga_id', 'versao'], 'vaga_versoes_unique_versao');
        });

        DB::statement('ALTER TABLE vaga_versoes ADD CONSTRAINT vaga_versoes_versao_positiva CHECK (versao > 0)');

        // Imutabilidade append-only (ADR-013 Decisão 1; padrão ADR-010).
        DB::unprepared('
            CREATE OR REPLACE FUNCTION prevent_vaga_versoes_mutation()
            RETURNS TRIGGER LANGUAGE plpgsql AS $$
            BEGIN
                RAISE EXCEPTION \'vaga_versoes é append-only — operação % não permitida\', TG_OP;
            END;
            $$;
        ');

        DB::unprepared('
            CREATE TRIGGER prevent_vaga_versoes_mutation
            BEFORE UPDATE OR DELETE ON vaga_versoes
            FOR EACH ROW EXECUTE FUNCTION prevent_vaga_versoes_mutation();
        ');

        $runtimeUser = config('database.connections.pgsql.username', 'turni');
        DB::unprepared("REVOKE UPDATE, DELETE ON vaga_versoes FROM \"{$runtimeUser}\"");
    }

    public function down(): void
    {
        DB::unprepared('DROP TRIGGER IF EXISTS prevent_vaga_versoes_mutation ON vaga_versoes');
        DB::unprepared('DROP FUNCTION IF EXISTS prevent_vaga_versoes_mutation()');
        Schema::dropIfExists('vaga_versoes');
    }
};
