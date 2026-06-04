<?php

// STORY-056 / ADR-016 (CA-5, Decisão 1A) — `pagamento_operacoes`: log + idempotência +
// correlação das operações financeiras da ACL Pagar.me (ADR-005), numa ÚNICA tabela.
//
// Por que uma tabela só: um turno tem ≤ 5 operações financeiras na vida e a relação com os
// ids do provedor é ~1:1 — normalizar a correlação numa 2ª tabela é complexidade sem dor
// real (princípio #1). As colunas `pagarme_*` são uma PROJEÇÃO desnormalizada da resposta,
// para consulta direta sem reparsear o jsonb.
//
// Idempotência (ADR-016 b): o índice ÚNICO (turno_id, tipo_operacao) é a barreira de
// hardware contra duplicação — o banco recusa a 2ª pré-autorização do mesmo turno. A chave
// determinística `"{tipo}:{turno_id}"` também viaja como Idempotency-Key ao provedor.
//
// Diferente de aceites_eletronicos_turno (ADR-015, imutável por trigger), esta tabela é
// MUTÁVEL: uma operação `pendente` → `concluida`/`falhou` precisa de UPDATE. A imutabilidade
// financeira mora na trilha de auditoria do turno (ADR-015), não aqui.
//
// ADR-018: id UUIDv7 PK; turno_id foreignUuid. down() simétrico (F-NB-1).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pagamento_operacoes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('turno_id')->constrained('turnos')->restrictOnDelete();

            // Vocabulário do domínio (App\Enums\TipoOperacaoPagamento / StatusOperacaoPagamento).
            $table->text('tipo_operacao');
            $table->text('idempotencia_chave')->unique(); // "{tipo}:{turno_id}" — ADR-005 d
            $table->text('status')->default('pendente');

            // Payloads completos (snapshot explicável — disciplina W27 STORY-051). Sem PII em
            // claro: a chave Pix NÃO é persistida aqui (mascarada na origem — ADR-016 g).
            $table->jsonb('request_payload')->nullable();
            $table->jsonb('response_payload')->nullable();

            // Correlação desnormalizada com o Pagar.me (identificadores opacos, não PII).
            $table->text('pagarme_order_id')->nullable();
            $table->text('pagarme_charge_id')->nullable();
            $table->text('pagarme_transfer_id')->nullable();

            $table->text('erro')->nullable(); // mensagem da falha (status = falhou)
            $table->timestampsTz();

            // Índice ÚNICO composto = garantia de não-duplicação (ADR-016 b). Redundante com o
            // unique de idempotencia_chave, mas explícito sobre a INVARIANTE de negócio.
            $table->unique(['turno_id', 'tipo_operacao']);
        });

        // Defesa de integridade no banco: tipo_operacao e status só aceitam os rótulos do enum.
        DB::statement("
            ALTER TABLE pagamento_operacoes
            ADD CONSTRAINT pagamento_operacoes_tipo_chk
            CHECK (tipo_operacao IN ('pre_autorizacao','captura','captura_parcial','liberacao','pix'))
        ");
        DB::statement("
            ALTER TABLE pagamento_operacoes
            ADD CONSTRAINT pagamento_operacoes_status_chk
            CHECK (status IN ('pendente','concluida','falhou'))
        ");
    }

    public function down(): void
    {
        Schema::dropIfExists('pagamento_operacoes');
    }
};
