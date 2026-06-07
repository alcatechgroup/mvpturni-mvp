<?php

// STORY-067 (CA-1) — 8 valores novos no enum nativo `notificacao_tipo` (eventos do turno).
// ALTER TYPE ... ADD VALUE não roda dentro de transação no Postgres → $withinTransaction = false
// e IF NOT EXISTS para idempotência. down() é no-op: Postgres não suporta DROP VALUE de enum e
// remover exigiria recriar o tipo + reescrever a coluna — aceito como migração só-de-ida (o
// rollback real é o down() da create_notificacoes_table, que dropa o tipo inteiro).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /** ALTER TYPE ADD VALUE é proibido em transação (Postgres). */
    public $withinTransaction = false;

    private const TIPOS = [
        'turno_confirmado',
        'checkin_solicitado',
        'turno_ativo',
        'checkout_solicitado',
        'turno_finalizado',
        'pix_enviado',
        'turno_cancelado',
        'no_show_pro',
    ];

    public function up(): void
    {
        foreach (self::TIPOS as $tipo) {
            DB::statement("ALTER TYPE notificacao_tipo ADD VALUE IF NOT EXISTS '{$tipo}'");
        }
    }

    public function down(): void
    {
        // No-op deliberado (ver cabeçalho).
    }
};
