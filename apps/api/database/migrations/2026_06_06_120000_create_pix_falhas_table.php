<?php

// STORY-065 (CA-5, CA-8) — `pix_falhas`: a fila de tratamento manual do admin (PDR-010:
// Pix tem UMA tentativa, sem retry automático — falha vira alerta destacado no Backoffice).
//
// Uma linha = um caso operacional. Nasce de: (a) webhook `transfer.failed` do gateway
// (fonte de verdade — CA-6, inclusive falha reportada APÓS sucesso aparente), (b) falha
// fatal síncrona do `transferirPix`, (c) chave Pix ausente no perfil, (d) tentativas do
// worker esgotadas com a captura já concluída (dinheiro entrou, Pix não saiu).
//
// UNIQUE(turno_id): PDR-010 garante no máximo um Pix por turno → no máximo um caso. Novo
// evento de falha para caso aberto ATUALIZA a razão (CA-6 — "alerta é atualizado"); caso
// já resolvido permanece resolvido (a resolução é decisão humana auditada, imutável aqui;
// trilha completa nos audit logs `pix.falhou`/`pix.falha_resolvida`).
//
// A chave Pix NÃO mora aqui (PII — ADR-016 g): o Backoffice a lê do perfil do profissional
// na hora de exibir. `razao` é o erro retornado pelo gateway (código — mensagem).
//
// ADR-018: id UUIDv7 PK; turno_id foreignUuid. down() simétrico (F-NB-1).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pix_falhas', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('turno_id')->unique()->constrained('turnos')->restrictOnDelete();

            // Snapshot operacional do caso no instante da falha (decisão da sessão,
            // aprovada em chat): o Backoffice lê UMA tabela, sem joins com turnos/vagas
            // (e sem replicar essas migrações para os testes do admin). O caso é um
            // registro arquivístico — vale o estado de quando a falha aconteceu.
            $table->text('profissional_nome')->nullable();
            $table->text('funcao')->nullable();
            $table->text('estabelecimento')->nullable();
            $table->decimal('valor', 10, 2)->nullable(); // o que o admin vai transferir

            // Chave Pix cifrada com segredo DEDICADO compartilhado api+admin (IDR-028;
            // App\Casts\ChavePixCompartilhada) — nunca em claro em repouso (ADR-016 g).
            $table->text('chave_pix')->nullable();

            $table->text('razao');                       // erro do gateway (Pagar.me-compatível)
            $table->jsonb('payload_gateway')->nullable(); // snapshot do data do webhook (sem PII)
            $table->timestampTz('falhou_em');

            // Resolução manual (CA-8): nota obrigatória na UI; quem e quando para a coluna
            // "Resolução" da aba Resolvidos. FK em users (admin) — nullOnDelete preserva o caso.
            $table->timestampTz('resolvido_em')->nullable();
            $table->foreignUuid('resolvido_por')->nullable()->constrained('users')->nullOnDelete();
            $table->text('nota_resolucao')->nullable();

            $table->timestampsTz();

            $table->index(['resolvido_em', 'falhou_em']); // fila pendente ordenada desc (CA-8)
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pix_falhas');
    }
};
