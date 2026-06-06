<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * STORY-066 (CA-4/CA-5) — duas mudanças de invariante:
 *
 * 1. Máquina de estados ganha a 14ª transição: `confirmado → no_show_pro`. O CA-5 manda o
 *    cron detectar turnos vencidos TAMBÉM em `confirmado` (profissional que nunca gerou o
 *    PIN), não só em `aguardando_checkin` (que já estava nas 13 da STORY-055). O trigger e
 *    o enum TurnoStatus mudam JUNTOS (devem concordar — qualquer divergência é bug).
 *
 * 2. `pix_falhas` vira a fila operacional generalizada "Falhas de pagamento" (CA-4 — mesma
 *    fila da STORY-065; rename validado pelo PO em 2026-06-06): coluna `tipo`
 *    ('pix' | 'liberacao') distingue o caso. Liberação não tem chave Pix (o tratamento é
 *    no gateway) e o valor do caso é o total reservado do contratante.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared($this->triggerComTransicoes(comNoShowDeConfirmado: true));

        Schema::table('pix_falhas', function (Blueprint $table) {
            $table->text('tipo')->default('pix'); // casos pré-066 são todos de Pix
        });
        DB::statement("ALTER TABLE pix_falhas ADD CONSTRAINT pix_falhas_tipo_valido CHECK (tipo IN ('pix', 'liberacao'))");
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE pix_falhas DROP CONSTRAINT pix_falhas_tipo_valido');
        Schema::table('pix_falhas', function (Blueprint $table) {
            $table->dropColumn('tipo');
        });

        DB::unprepared($this->triggerComTransicoes(comNoShowDeConfirmado: false));
    }

    /** CREATE OR REPLACE da função do trigger (criado na 2026_06_03_150000) — fonte única aqui. */
    private function triggerComTransicoes(bool $comNoShowDeConfirmado): string
    {
        $deConfirmado = $comNoShowDeConfirmado
            ? "('aguardando_checkin', 'cancelado_pro', 'cancelado_emp', 'no_show_pro')"
            : "('aguardando_checkin', 'cancelado_pro', 'cancelado_emp')";

        return "
            CREATE OR REPLACE FUNCTION enforce_turno_transition()
            RETURNS TRIGGER LANGUAGE plpgsql AS \$\$
            BEGIN
                IF NEW.status IS DISTINCT FROM OLD.status THEN
                    IF NOT (
                        -- de confirmado (4 — STORY-066 adiciona no_show_pro)
                        (OLD.status = 'confirmado'          AND NEW.status IN {$deConfirmado})
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
        ";
    }
};
