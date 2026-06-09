<?php

// STORY-085 (CA-2) — novo valor no enum nativo `notificacao_tipo`: `avaliacao_pendente`
// (notificação "avalie seu turno" aos DOIS lados quando o turno finaliza — ADR-019 Decisão 3).
// ALTER TYPE ... ADD VALUE não roda em transação no Postgres → $withinTransaction = false +
// IF NOT EXISTS para idempotência. down() no-op (Postgres não suporta DROP VALUE; o rollback
// real é o down() da create_notificacoes_table, que dropa o tipo inteiro) — mesmo padrão da
// add_turno_tipos_to_notificacao_tipo (STORY-067).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public $withinTransaction = false;

    public function up(): void
    {
        DB::statement("ALTER TYPE notificacao_tipo ADD VALUE IF NOT EXISTS 'avaliacao_pendente'");
    }

    public function down(): void
    {
        // No-op deliberado (ver cabeçalho).
    }
};
