<?php

// STORY-056 / ADR-016 (CA-6, e) — `webhook_eventos_pagarme`: deduplicação dos webhooks
// entrantes do Pagar.me. O provedor entrega "at-least-once" (`integration-architecture.md`
// §webhook): o mesmo `event_id` pode chegar mais de uma vez — a 1ª vez processa, as demais
// respondem 200 sem reprocessar. `event_id` único é a barreira.
//
// ADR-018: id UUIDv7 PK. `processado_em` marca quando o job concluiu (null = enfileirado).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('webhook_eventos_pagarme', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->text('event_id')->unique(); // id do evento no Pagar.me — dedup
            $table->text('tipo')->nullable();   // type do provedor (ex.: charge.paid)
            $table->text('turno_id')->nullable(); // external_reference (UUID string)
            $table->jsonb('payload');           // evento bruto recebido
            $table->timestampTz('recebido_em');
            $table->timestampTz('processado_em')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('webhook_eventos_pagarme');
    }
};
