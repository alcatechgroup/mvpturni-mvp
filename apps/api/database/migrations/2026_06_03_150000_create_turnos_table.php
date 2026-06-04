<?php

// STORY-055 / ADR-015 (CA-2, CA-4, CA-5, CA-6) — tabela `turnos`: a unidade central do
// produto (domain/turno.md). Nasce de uma candidatura aprovada e percorre a máquina de
// estados até um terminal.
//  - `status` em enum NATIVO do Postgres (`turno_status`) — os 11 estados de turno.md;
//  - MÁQUINA DE ESTADOS como INVARIANTE DE BANCO (CA-4): trigger BEFORE UPDATE valida as
//    13 transições válidas; transição inválida (ex.: confirmado→finalizado) levanta erro.
//    Diferença consciente de ADR-013 (que pôs transições só no domínio): aqui a garantia
//    jurídica/operacional ("nunca dois check-outs", "nunca pular para finalizado") precisa
//    ser à prova de SQL cru — CA-4. O enum PHP TurnoStatus espelha para ergonomia/testes.
//  - PKs/FKs em UUID (ADR-018); estabelecimento_id = contratante_id no MVP (sem entidade
//    Estabelecimento separada — convenção GateHabitualidade/STORY-050);
//  - índices CA-5, incl. o composto de habitualidade de ADR-006 sobre a tabela-alvo (turno).
// down() simétrico: drop table → drop function → drop type (F-NB-1).

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Os 11 estados de domain/turno.md, enum nativo (CA-2).
        DB::statement("CREATE TYPE turno_status AS ENUM (
            'confirmado',
            'aguardando_checkin',
            'ativo',
            'aguardando_checkout',
            'em_disputa',
            'finalizado',
            'finalizado_ajustado',
            'disputa_resolvida_sem_pagamento',
            'cancelado_pro',
            'cancelado_emp',
            'no_show_pro'
        )");

        Schema::create('turnos', function (Blueprint $table) {
            $table->uuid('id')->primary();

            // Origem: candidatura aprovada (1 turno por candidatura — UNIQUE abaixo).
            $table->foreignUuid('candidatura_id')->constrained('candidaturas')->restrictOnDelete();
            $table->foreignUuid('vaga_id')->constrained('vagas')->restrictOnDelete();
            // Versão da vaga vigente no aceite (snapshot herdado de ADR-013/PDR-009).
            $table->foreignUuid('vaga_versao_id')->nullable()->constrained('vaga_versoes')->nullOnDelete();
            $table->foreignUuid('profissional_id')->constrained('users')->restrictOnDelete();
            $table->foreignUuid('contratante_id')->constrained('users')->restrictOnDelete();
            // estabelecimento_id = contratante_id no MVP; coluna separada honra o par de
            // habitualidade de ADR-006/PDR-002 e prepara multi-unidade (compliance.md §lacunas).
            $table->foreignUuid('estabelecimento_id')->constrained('users')->restrictOnDelete();

            // `status` é adicionado via ALTER (enum nativo — Laravel não tem builder próprio).

            // Financeiro congelado no aceite (PDR-004 / domain/pagamento.md).
            $table->decimal('valor', 10, 2);            // o que o profissional recebe
            $table->decimal('taxa_turni', 10, 2);       // taxa do contratante (15% MVP)
            $table->decimal('total_contratante', 10, 2); // valor + taxa_turni (pré-autorizado)

            // Janela do turno (cópia da vaga, congelada).
            $table->timestampTz('data_inicio');
            $table->timestampTz('data_fim');

            // Timestamps de check-in/out validados (carimbados nas transições).
            $table->timestampTz('check_in_at')->nullable();
            $table->timestampTz('check_out_at')->nullable();

            // Geofencing alerta-e-registra (PDR-008): { ok, distancia_metros, capturado_em, razao? }.
            $table->jsonb('geofencing_check_in')->nullable();
            $table->jsonb('geofencing_check_out')->nullable();

            // Cancelamento (PDR-007): { lado, motivo?, antecedencia_horas, em }.
            $table->jsonb('cancelamento')->nullable();

            $table->timestampsTz();

            // 1 turno por candidatura aprovada (invariante de origem).
            $table->unique('candidatura_id', 'turnos_unique_candidatura');
        });

        DB::statement("ALTER TABLE turnos ADD COLUMN status turno_status NOT NULL DEFAULT 'confirmado'");

        // Invariantes duras no banco (CA-2/CA-4).
        // Consistência financeira: total = valor + taxa (a regra dos 15% vive no domínio).
        DB::statement('ALTER TABLE turnos ADD CONSTRAINT turnos_total_consistente CHECK (total_contratante = valor + taxa_turni)');
        DB::statement('ALTER TABLE turnos ADD CONSTRAINT turnos_valores_nao_negativos CHECK (valor >= 0 AND taxa_turni >= 0)');
        DB::statement('ALTER TABLE turnos ADD CONSTRAINT turnos_datas_ordem CHECK (data_fim > data_inicio)');

        // ── Máquina de estados como invariante de banco (CA-4) ──────────────────────────
        // As 13 transições válidas de domain/turno.md. Só valida quando `status` muda
        // (UPDATE de check_in_at, geofencing etc. passa livre). Fail-closed: qualquer par
        // não listado levanta exceção — impossível pular estados mesmo via SQL cru.
        DB::unprepared("
            CREATE OR REPLACE FUNCTION enforce_turno_transition()
            RETURNS TRIGGER LANGUAGE plpgsql AS \$\$
            BEGIN
                IF NEW.status IS DISTINCT FROM OLD.status THEN
                    IF NOT (
                        -- de confirmado (3)
                        (OLD.status = 'confirmado'          AND NEW.status IN ('aguardando_checkin', 'cancelado_pro', 'cancelado_emp'))
                        -- de aguardando_checkin (3)
                        OR (OLD.status = 'aguardando_checkin'  AND NEW.status IN ('ativo', 'confirmado', 'no_show_pro'))
                        -- de ativo (1)
                        OR (OLD.status = 'ativo'               AND NEW.status = 'aguardando_checkout')
                        -- de aguardando_checkout (3)
                        OR (OLD.status = 'aguardando_checkout' AND NEW.status IN ('finalizado', 'em_disputa', 'ativo'))
                        -- de em_disputa (3)
                        OR (OLD.status = 'em_disputa'          AND NEW.status IN ('finalizado', 'finalizado_ajustado', 'disputa_resolvida_sem_pagamento'))
                    ) THEN
                        RAISE EXCEPTION 'transição de turno inválida: % → % (turno %)', OLD.status, NEW.status, OLD.id;
                    END IF;
                END IF;
                RETURN NEW;
            END;
            \$\$;
        ");

        DB::unprepared('
            CREATE TRIGGER enforce_turno_transition
            BEFORE UPDATE ON turnos
            FOR EACH ROW EXECUTE FUNCTION enforce_turno_transition();
        ');

        // ── Índices (CA-5) ──────────────────────────────────────────────────────────────
        // "Meus turnos" do profissional, agrupados por estado (STORY-059).
        DB::statement('CREATE INDEX idx_turnos_profissional_status ON turnos (profissional_id, status)');
        // "Vagas confirmadas" do contratante, por estado (STORY-059).
        DB::statement('CREATE INDEX idx_turnos_contratante_status ON turnos (contratante_id, status)');
        // Habitualidade (ADR-006/PDR-002): contagem por (estabelecimento, profissional) na
        // semana corrida da vaga — range scan estreito sobre data_inicio. Tabela-alvo é o turno.
        DB::statement('CREATE INDEX idx_turnos_habitualidade ON turnos (estabelecimento_id, profissional_id, data_inicio)');
    }

    public function down(): void
    {
        DB::unprepared('DROP TRIGGER IF EXISTS enforce_turno_transition ON turnos');
        DB::unprepared('DROP FUNCTION IF EXISTS enforce_turno_transition()');
        Schema::dropIfExists('turnos');
        DB::statement('DROP TYPE IF EXISTS turno_status');
    }
};
