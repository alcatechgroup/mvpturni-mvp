<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * STORY-053 (CA-12) — remove os dados de smoke/E2E criados em homolog: usuários de teste com e-mail
 * ENTREGÁVEL (`xandroalmeida+<alias>@gmail.com`), suas vagas, versões, candidaturas e notificações.
 *
 * Seguro por construção: só toca usuários cujo e-mail casa `xandroalmeida+%@gmail.com` (aliases de
 * teste) — nunca usuários reais. Requer `--force`. Deleta em ordem FK-safe dentro de uma transação;
 * `vaga_versoes` é append-only (REVOKE DELETE), então concedemos DELETE temporariamente (turni é dono)
 * e revogamos de volta no fim da transação.
 */
class LimparDadosCa12SmokeCommand extends Command
{
    protected $signature = 'ca12:limpar-smoke {--force : Confirma a remoção}';

    protected $description = 'Remove os dados de smoke/E2E do CA-12 (usuários xandroalmeida+%@gmail.com e dependências).';

    public function handle(): int
    {
        if (! $this->option('force')) {
            $this->error('Use --force para confirmar.');

            return self::FAILURE;
        }

        $userIds = DB::table('users')->where('email', 'like', 'xandroalmeida+%@gmail.com')->pluck('id')->all();
        if ($userIds === []) {
            $this->info('Nada a limpar (nenhum usuário de teste xandroalmeida+%@gmail.com).');

            return self::SUCCESS;
        }

        $vagaIds = DB::table('vagas')->whereIn('contratante_id', $userIds)->pluck('id')->all();

        $runtimeUser = config('database.connections.pgsql.username', 'turni');

        DB::transaction(function () use ($userIds, $vagaIds, $runtimeUser) {
            // vaga_versoes é append-only por DUAS camadas: REVOKE DELETE (privilégio) + trigger
            // prevent_vaga_versoes_mutation (BEFORE DELETE → RAISE). turni é dono → concede o DELETE e
            // desabilita o trigger SÓ dentro desta transação; restaura ambos no fim (rollback também).
            DB::unprepared("GRANT DELETE ON vaga_versoes TO \"{$runtimeUser}\"");
            DB::statement('ALTER TABLE vaga_versoes DISABLE TRIGGER prevent_vaga_versoes_mutation');

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
            $u = DB::table('users')->whereIn('id', $userIds)->delete();

            DB::statement('ALTER TABLE vaga_versoes ENABLE TRIGGER prevent_vaga_versoes_mutation');
            DB::unprepared("REVOKE DELETE ON vaga_versoes FROM \"{$runtimeUser}\"");

            $this->info("Removidos: notificacoes={$n} candidaturas={$c} vaga_versoes={$vv} vagas={$v} users={$u}.");
        });

        return self::SUCCESS;
    }
}
