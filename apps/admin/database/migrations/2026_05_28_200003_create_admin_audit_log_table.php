<?php

// STORY-016 — CA-1, CA-15 — Audit log append-only com imutabilidade garantida
// via trigger BEFORE UPDATE/DELETE + REVOKE no role de runtime (ADR-009 Decisão 4A).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_audit_log', function (Blueprint $table) {
            // GENERATED ALWAYS AS IDENTITY garante que o app nunca injeta ID manualmente
            $table->id();
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('action', 100);
            $table->string('target_type', 100)->nullable();
            $table->unsignedBigInteger('target_id')->nullable();
            $table->jsonb('payload')->nullable();
            $table->ipAddress('ip')->nullable();
            $table->text('user_agent')->nullable();
            // Sem updated_at — tabela append-only
            $table->timestampTz('created_at')->default(DB::raw('NOW()'));
        });

        // Trigger de imutabilidade: qualquer UPDATE ou DELETE levanta exceção (ADR-009 Decisão 4A).
        DB::unprepared('
            CREATE OR REPLACE FUNCTION prevent_admin_audit_log_mutation()
            RETURNS TRIGGER LANGUAGE plpgsql AS $$
            BEGIN
                RAISE EXCEPTION \'Audit log is immutable — operation % not allowed on admin_audit_log\', TG_OP;
            END;
            $$;
        ');

        DB::unprepared('
            CREATE TRIGGER prevent_admin_audit_log_mutation
            BEFORE UPDATE OR DELETE ON admin_audit_log
            FOR EACH ROW EXECUTE FUNCTION prevent_admin_audit_log_mutation();
        ');

        // REVOKE UPDATE e DELETE do usuário de runtime (ADR-009 Decisão 4A).
        // O usuário turni_app_runtime é o usuário que a aplicação usa em produção/homolog.
        // Em ambiente de testes (DB_USERNAME=turni), aplica o REVOKE ao usuário turni.
        $runtimeUser = config('database.connections.pgsql.username', 'turni');
        DB::unprepared("REVOKE UPDATE, DELETE ON admin_audit_log FROM \"{$runtimeUser}\"");
    }

    public function down(): void
    {
        DB::unprepared('DROP TRIGGER IF EXISTS prevent_admin_audit_log_mutation ON admin_audit_log');
        DB::unprepared('DROP FUNCTION IF EXISTS prevent_admin_audit_log_mutation()');
        Schema::dropIfExists('admin_audit_log');
    }
};
