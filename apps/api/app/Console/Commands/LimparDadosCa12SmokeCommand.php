<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * STORY-053 (CA-12) — remove os dados de smoke/E2E criados em homolog: usuários de teste com e-mail
 * ENTREGÁVEL (`xandroalmeida+<alias>@gmail.com`), suas vagas, versões, candidaturas e notificações.
 *
 * Seguro por construção: só toca usuários cujo e-mail casa `xandroalmeida+%@gmail.com` (aliases de
 * teste) — nunca usuários reais. Requer `--force`.
 *
 * Lida com a arquitetura append-only: `vaga_versoes` (deletamos linhas), `audit_logs` e
 * `admin_audit_log` (FK `actor_id` nullOnDelete → o delete de users dispara UPDATE SET NULL) têm
 * REVOKE + trigger de imutabilidade. turni é DONO → concede o privilégio e desabilita os triggers
 * de usuário (`DISABLE TRIGGER USER` mantém os triggers de FK/RI) só dentro da transação, e restaura
 * tudo no fim (rollback também restaura).
 */
class LimparDadosCa12SmokeCommand extends Command
{
    protected $signature = 'ca12:limpar-smoke {--force : Confirma a remoção} {--like=xandroalmeida+%-homolog@gmail.com : Padrão LIKE do e-mail dos usuários de teste a remover}';

    protected $description = 'Remove os dados de smoke/E2E do CA-12 (usuários de teste `-homolog` e dependências).';

    public function handle(): int
    {
        if (! $this->option('force')) {
            $this->error('Use --force para confirmar.');

            return self::FAILURE;
        }

        // Default: só os aliases que o Ca12EmailSmokeSeeder cria (sufixo `-homolog`). NÃO pega outros
        // `xandroalmeida+...@gmail.com` de testes alheios (que podem ter aceite e travariam o delete).
        $like = (string) $this->option('like');
        $users = DB::table('users')->where('email', 'like', $like)->pluck('email', 'id');
        if ($users->isEmpty()) {
            $this->info("Nada a limpar (nenhum usuário like {$like}).");

            return self::SUCCESS;
        }

        $userIds = $users->keys()->all();
        $this->info('Usuários de teste a remover ('.count($userIds).'): '.$users->values()->implode(', '));

        $vagaIds = DB::table('vagas')->whereIn('contratante_id', $userIds)->pluck('id')->all();
        $ru = config('database.connections.pgsql.username', 'turni');

        DB::transaction(function () use ($userIds, $vagaIds, $ru) {
            // Levanta a imutabilidade SÓ nesta transação. vaga_versoes: precisamos DELETE.
            // audit_logs/admin_audit_log: o delete de users dispara UPDATE SET NULL (actor_id).
            DB::unprepared("GRANT DELETE ON vaga_versoes TO \"{$ru}\"");
            DB::unprepared("GRANT UPDATE ON audit_logs TO \"{$ru}\"");
            DB::unprepared("GRANT UPDATE ON admin_audit_log TO \"{$ru}\"");
            // aceites_eletronicos: FK `user_id` é RESTRICT (NO ACTION) e a tabela é append-only
            // (REVOKE UPDATE,DELETE + trigger — ADR-010). Para apagar o usuário de teste é preciso
            // (a) remover o aceite ANTES do delete de users — exige DELETE; e (b) a trava
            // `SELECT ... FOR KEY SHARE` que o delete de users faz na tabela referenciante exige
            // UPDATE (mesma razão do GRANT UPDATE em vaga_versoes — STORY-053). Concede ambos e
            // desabilita o trigger só nesta transação.
            DB::unprepared("GRANT UPDATE, DELETE ON aceites_eletronicos TO \"{$ru}\"");
            foreach (['vaga_versoes', 'audit_logs', 'admin_audit_log', 'aceites_eletronicos'] as $t) {
                DB::statement("ALTER TABLE {$t} DISABLE TRIGGER USER");
            }

            $n = DB::table('notificacoes')
                ->whereIn('destinatario_id', $userIds)
                ->when($vagaIds !== [], fn ($q) => $q->orWhereIn('vaga_id', $vagaIds))
                ->delete();

            $c = DB::table('candidaturas')
                ->when($vagaIds !== [], fn ($q) => $q->whereIn('vaga_id', $vagaIds))
                ->orWhereIn('profissional_id', $userIds)
                ->delete();

            $vv = $vagaIds !== [] ? DB::table('vaga_versoes')->whereIn('vaga_id', $vagaIds)->delete() : 0;
            $v = $vagaIds !== [] ? DB::table('vagas')->whereIn('id', $vagaIds)->delete() : 0;

            DB::table('contratante_profiles')->whereIn('user_id', $userIds)->delete();
            DB::table('profissional_profiles')->whereIn('user_id', $userIds)->delete();
            $ae = DB::table('aceites_eletronicos')->whereIn('user_id', $userIds)->delete();
            $u = DB::table('users')->whereIn('id', $userIds)->delete();

            foreach (['vaga_versoes', 'audit_logs', 'admin_audit_log', 'aceites_eletronicos'] as $t) {
                DB::statement("ALTER TABLE {$t} ENABLE TRIGGER USER");
            }
            DB::unprepared("REVOKE DELETE ON vaga_versoes FROM \"{$ru}\"");
            DB::unprepared("REVOKE UPDATE ON audit_logs FROM \"{$ru}\"");
            DB::unprepared("REVOKE UPDATE ON admin_audit_log FROM \"{$ru}\"");
            DB::unprepared("REVOKE UPDATE, DELETE ON aceites_eletronicos FROM \"{$ru}\"");

            $this->info("Removidos: notificacoes={$n} candidaturas={$c} vaga_versoes={$vv} vagas={$v} aceites={$ae} users={$u}.");
        });

        return self::SUCCESS;
    }
}
