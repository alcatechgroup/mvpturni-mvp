<?php

// STORY-053 (CA-1) — `notificacoes`: caixa in-app + fila implícita de e-mail.
//  - `tipo` em enum NATIVO do Postgres (`notificacao_tipo`) — mesmo padrão de candidatura_estado/vaga_estado;
//  - `payload` jsonb com as variáveis de cada template (interpolação do corpo do e-mail e do resumo in-app);
//  - `enviada_email_em IS NULL AND falha_envio_em IS NULL` é a FILA IMPLÍCITA do worker (CA-5, liberdade técnica:
//    sem Redis/Beanstalkd no MVP); `tentativas_envio` conta o retry entre execuções do worker (1/min);
//  - `idempotency_key` UNIQUE: o mesmo evento disparado 2x não gera 2 notificações (story §"Idempotência");
//  - índice (destinatario_id, lida_em, criada_em DESC) para a caixa in-app (CA-7 lista as não-lidas/últimas 50).
// down() simétrico: drop table → drop type (F-NB-1, padrão do projeto).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("CREATE TYPE notificacao_tipo AS ENUM (
            'candidatura_recebida',
            'vaga_editada_material',
            'vaga_cancelada',
            'vaga_editada_material_candidatura_mantida',
            'vaga_editada_material_candidatura_retirada'
        )");

        Schema::create('notificacoes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            // `tipo` adicionado via ALTER (enum nativo).
            $table->foreignUuid('destinatario_id')->constrained('users')->restrictOnDelete();
            // Vaga/candidatura de contexto — nullable + nullOnDelete: a notificação sobrevive
            // ao (improvável) sumiço do alvo; vagas/candidaturas no MVP transitam de estado,
            // não são apagadas.
            $table->foreignUuid('vaga_id')->nullable()->constrained('vagas')->nullOnDelete();
            $table->foreignUuid('candidatura_id')->nullable()->constrained('candidaturas')->nullOnDelete();
            $table->jsonb('payload')->nullable();
            // Idempotência (story §"Idempotência"): "<tipo>:<candidatura_id>[:<vaga_versao>]".
            $table->string('idempotency_key', 191)->unique();
            $table->timestampTz('lida_em')->nullable();
            // Fila implícita de e-mail (CA-5): NULL = ainda não enviado.
            $table->timestampTz('enviada_email_em')->nullable();
            // Falha permanente após esgotar tentativas (CA-5): NULL = sem falha definitiva.
            $table->timestampTz('falha_envio_em')->nullable();
            $table->unsignedSmallInteger('tentativas_envio')->default(0);
            // A estória nomeia explicitamente `criada_em` (≠ created_at do Eloquent).
            $table->timestampTz('criada_em')->default(DB::raw('NOW()'));
        });

        DB::statement('ALTER TABLE notificacoes ADD COLUMN tipo notificacao_tipo NOT NULL');

        // Caixa in-app (CA-7): não-lidas/últimas 50 do destinatário, mais recentes primeiro.
        DB::statement('CREATE INDEX idx_notificacoes_destinatario ON notificacoes (destinatario_id, lida_em, criada_em DESC)');
        // Fila do worker (CA-5): só as pendentes de envio, ordenadas por criação (FIFO).
        DB::statement('CREATE INDEX idx_notificacoes_fila_email ON notificacoes (criada_em)
            WHERE enviada_email_em IS NULL AND falha_envio_em IS NULL');
    }

    public function down(): void
    {
        Schema::dropIfExists('notificacoes');
        DB::statement('DROP TYPE IF EXISTS notificacao_tipo');
    }
};
