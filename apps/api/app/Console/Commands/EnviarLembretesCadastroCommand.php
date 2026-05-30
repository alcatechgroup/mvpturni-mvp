<?php

namespace App\Console\Commands;

use App\Models\CadastroLembrete;
use App\Models\User;
use App\Services\AuditLogService;
use Illuminate\Console\Command;
use Illuminate\Database\QueryException;
use Turni\Domain\Email\EmailTransacional;
use Turni\Domain\Email\EnviarEmailTransacionalJob;
use Turni\Domain\Email\TipoEmail;

/**
 * Lembrete de completar cadastro (STORY-021 CA-5).
 *
 * Roda 1×/dia (agendado em routes/console.php, 09:00 BRT). Para cada usuário
 * `liberado`, com welcome visto e cadastro NÃO concluído, envia até 3 lembretes —
 * em 48h, 5 dias e 14 dias após a aprovação. A tabela `cadastro_lembretes`
 * (única por user+numero) garante idempotência: rodar o scheduler mais de uma vez
 * no dia não reenvia. Ao 3º lembrete (14 dias), além de enviar, grava UMA observação
 * no audit log (`admin.user.cadastro_pendente_expirado`) e para — `horas_pendente`
 * vai no contrato do e-mail mas não aparece no corpo (decisão de tom — SCREEN §5.2).
 */
class EnviarLembretesCadastroCommand extends Command
{
    protected $signature = 'lembretes:cadastro';

    protected $description = 'Envia lembretes de completar cadastro (48h/5d/14d após aprovação) — STORY-021 CA-5.';

    /** Janela de cada lembrete em horas desde a aprovação. */
    private const JANELAS_HORAS = [1 => 48, 2 => 120, 3 => 336];

    private const TETO = 3;

    public function handle(AuditLogService $auditLog): int
    {
        $agora = now();

        $candidatos = User::query()
            ->where('status', 'liberado')
            ->whereNotNull('aprovado_em')
            ->whereNotNull('welcome_seen_at')
            ->whereNull('cadastro_completed_at')
            ->get();

        $enviados = 0;

        foreach ($candidatos as $user) {
            $jaEnviados = CadastroLembrete::where('user_id', $user->getKey())->count();

            if ($jaEnviados >= self::TETO) {
                continue; // teto atingido — não envia mais (ADR-011 / story §2).
            }

            $numero = $jaEnviados + 1;

            // Ainda não atingiu a janela deste lembrete → espera.
            if ($user->aprovado_em->isAfter($agora->copy()->subHours(self::JANELAS_HORAS[$numero]))) {
                continue;
            }

            // Marca a intenção de forma idempotente: a unique (user_id, numero) barra
            // corrida entre execuções concorrentes do scheduler (só uma cria a linha).
            try {
                CadastroLembrete::create([
                    'user_id' => $user->getKey(),
                    'numero' => $numero,
                    'enviado_em' => $agora,
                ]);
            } catch (QueryException) {
                continue;
            }

            EnviarEmailTransacionalJob::dispatch(new EmailTransacional(
                destinatario: $user->email,
                tipo: TipoEmail::LembreteCompletarCadastro,
                dados: [
                    'nome' => $user->name,
                    'link_completar' => config('app.webapp_url', config('app.url')),
                    'horas_pendente' => (int) abs($user->aprovado_em->diffInHours($agora)),
                ],
                idempotencyKey: "lembrete_completar_cadastro:{$user->getKey()}:{$numero}",
            ));

            $enviados++;

            // 3º lembrete (14 dias) = limite. Observação única para a equipe Turni
            // poder olhar manualmente (story §2). Idempotente: só ocorre no envio do
            // numero=3, que a unique já garante acontecer uma vez.
            if ($numero === self::TETO) {
                $auditLog->log(
                    action: 'admin.user.cadastro_pendente_expirado',
                    targetType: 'User',
                    targetId: $user->getKey(),
                    payload: [
                        'aprovado_em' => $user->aprovado_em->toIso8601String(),
                        'lembretes_enviados' => self::TETO,
                    ],
                );
            }
        }

        $this->info("Lembretes de cadastro despachados: {$enviados}.");

        return self::SUCCESS;
    }
}
