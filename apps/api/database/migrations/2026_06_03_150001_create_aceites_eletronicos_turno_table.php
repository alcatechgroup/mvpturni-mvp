<?php

// STORY-055 / ADR-015 (CA-3) — `aceites_eletronicos_turno`: aceite eletrônico POR TURNO
// (compliance.md §"Aceite eletrônico por turno"). Espelha o padrão imutável de ADR-010
// (aceites_eletronicos do usuário/adesão do EPIC-001), mas é uma tabela SEPARADA: o aceite
// por turno carrega placeholders do turno e a cláusula de override de habitualidade
// (PDR-002 — 3ª alocação semanal de PJ aceita conscientemente). Por isso NÃO se reusa o
// `aceites_eletronicos` via `turno_id` (hint antigo de ADR-010): os artefatos são distintos.
//
// Convenção de nome (latitude do arquiteto — story §"Liberdade técnica"): o campo que
// compliance.md chama de `timestamp` vira a coluna `aceito_em` (evita a palavra reservada
// SQL e espelha ADR-010). Imutável: trigger BEFORE UPDATE/DELETE + REVOKE no role de runtime.
// down() simétrico (F-NB-1).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('aceites_eletronicos_turno', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('turno_id')->constrained('turnos')->restrictOnDelete();
            // Versão exata do template vigente no aceite (FK imutável — ADR-010).
            $table->foreignUuid('template_versao_id')->constrained('template_versoes');
            $table->text('conteudo_renderizado'); // documento integral exibido/assinado (autocontido)
            $table->jsonb('dados_renderizados');   // mapa placeholder -> valor (IDs como string UUID)
            $table->timestampTz('aceito_em')->default(DB::raw('NOW()')); // compliance.md `timestamp`
            $table->ipAddress('ip');
            $table->text('fingerprint'); // sha256(user_agent:ip:date) — ADR-010 Decisão 4
            // Cláusula de aceite consciente de risco: true na 3ª alocação semanal de PJ com
            // override aprovado pelo contratante (PDR-002 / compliance.md).
            $table->boolean('habitualidade_override')->default(false);
            // Sem updated_at: imutável após criação.
        });

        // Imutabilidade (ADR-010 Decisão 4A) — qualquer UPDATE/DELETE levanta exceção.
        DB::unprepared('
            CREATE OR REPLACE FUNCTION prevent_aceite_turno_mutation()
            RETURNS TRIGGER LANGUAGE plpgsql AS $$
            BEGIN
                RAISE EXCEPTION \'aceites_eletronicos_turno é imutável após criação — operação % não permitida\', TG_OP;
            END;
            $$;
        ');

        DB::unprepared('
            CREATE TRIGGER prevent_aceite_turno_mutation
            BEFORE UPDATE OR DELETE ON aceites_eletronicos_turno
            FOR EACH ROW EXECUTE FUNCTION prevent_aceite_turno_mutation();
        ');

        // Defesa em profundidade: runtime não tem UPDATE/DELETE mesmo se o trigger sumir.
        // Nada referencia esta tabela por FK (não é tabela-pai), então o REVOKE não esbarra
        // no lock de validação de FK que exigiu o GRANT de vaga_versoes (2026_06_03_140000).
        $runtimeUser = config('database.connections.pgsql.username', 'turni');
        DB::unprepared("REVOKE UPDATE, DELETE ON aceites_eletronicos_turno FROM \"{$runtimeUser}\"");
    }

    public function down(): void
    {
        DB::unprepared('DROP TRIGGER IF EXISTS prevent_aceite_turno_mutation ON aceites_eletronicos_turno');
        DB::unprepared('DROP FUNCTION IF EXISTS prevent_aceite_turno_mutation()');
        Schema::dropIfExists('aceites_eletronicos_turno');
    }
};
