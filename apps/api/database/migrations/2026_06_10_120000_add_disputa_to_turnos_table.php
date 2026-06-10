<?php

// STORY-092 / ADR-020 (Decisão 1A) — a disputa mora EMBUTIDA no turno como `turnos.disputa`
// jsonb nullable, no mesmo grão de `cancelamento`/`geofencing_*` (1:1, contextual, sem
// agregação cross-turno no MVP). Obrigatoriedade da justificativa e validade da `resolucao`
// vivem no comando de domínio (AbrirDisputaService/ResolverDisputaService), não em constraint
// de banco — jsonb não comporta CHECK de chave interna e a porta de entrada é sempre o service
// (a transição em si é invariante de banco pelo trigger `enforce_turno_transition`). A trilha
// imutável vem de `audit_logs` (turno.disputa_aberta/turno.disputa_resolvida).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('turnos', function (Blueprint $table) {
            $table->jsonb('disputa')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('turnos', function (Blueprint $table) {
            $table->dropColumn('disputa');
        });
    }
};
