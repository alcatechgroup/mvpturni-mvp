<?php

// STORY-044 / ADR-013 Decisão 5 (CA-6) — `audit_logs`: trilha GERAL de eventos de
// domínio (ator = qualquer usuário). Distinta do admin_audit_log (ações de admin,
// ADR-009) — não a reabre. Append-only: imutável no banco (trigger + REVOKE), mesmo
// padrão do admin_audit_log. down() simétrico (F-NB-1).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('audit_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('action', 100);
            $table->string('target_type', 100)->nullable();
            $table->uuid('target_id')->nullable();
            $table->jsonb('payload')->nullable();
            $table->ipAddress('ip')->nullable();
            $table->text('user_agent')->nullable();
            $table->timestampTz('created_at')->default(DB::raw('NOW()'));

            $table->index(['target_type', 'target_id']);
            $table->index('action');
        });

        DB::unprepared('
            CREATE OR REPLACE FUNCTION prevent_audit_logs_mutation()
            RETURNS TRIGGER LANGUAGE plpgsql AS $$
            BEGIN
                RAISE EXCEPTION \'audit_logs é append-only — operação % não permitida\', TG_OP;
            END;
            $$;
        ');

        DB::unprepared('
            CREATE TRIGGER prevent_audit_logs_mutation
            BEFORE UPDATE OR DELETE ON audit_logs
            FOR EACH ROW EXECUTE FUNCTION prevent_audit_logs_mutation();
        ');

        $runtimeUser = config('database.connections.pgsql.username', 'turni');
        DB::unprepared("REVOKE UPDATE, DELETE ON audit_logs FROM \"{$runtimeUser}\"");
    }

    public function down(): void
    {
        DB::unprepared('DROP TRIGGER IF EXISTS prevent_audit_logs_mutation ON audit_logs');
        DB::unprepared('DROP FUNCTION IF EXISTS prevent_audit_logs_mutation()');
        Schema::dropIfExists('audit_logs');
    }
};
