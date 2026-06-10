<?php

// STORY-092 (CA-6) — novo valor no enum nativo `notificacao_tipo`: `disputa_aberta`
// (notificação "valor em disputa — mediação em até 30 min" ao PROFISSIONAL quando o contratante
// abre a disputa — ADR-020 Decisão 4). ALTER TYPE ... ADD VALUE não roda em transação no
// Postgres → $withinTransaction = false + IF NOT EXISTS para idempotência. down() no-op
// (Postgres não suporta DROP VALUE; o rollback real é o down() da create_notificacoes_table,
// que dropa o tipo inteiro) — mesmo padrão de add_avaliacao_pendente_to_notificacao_tipo (085).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public $withinTransaction = false;

    public function up(): void
    {
        DB::statement("ALTER TYPE notificacao_tipo ADD VALUE IF NOT EXISTS 'disputa_aberta'");
    }

    public function down(): void
    {
        // No-op deliberado (ver cabeçalho).
    }
};
