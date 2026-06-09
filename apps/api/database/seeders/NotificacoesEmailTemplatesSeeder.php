<?php

namespace Database\Seeders;

use App\Enums\NotificacaoTipo;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * STORY-053 (CA-6, Path A) — os 5 corpos editáveis dos e-mails de notificação como `Template`
 * de categoria `email` + `TemplateVersao` v1 ativa.
 *
 * Mesmo padrão de TemplatesContratuaisSeeder (STORY-020): conteúdo vendorado em
 * `database/seeders/emails/` porque `docs/` não é montado no container (memória
 * `project-backoffice-db-ownership`). O slug de cada template segue
 * `NotificacaoTipo::templateSlug()` (`<tipo>_email`) — 1:1 com o tipo de notificação, que é como
 * o worker (CA-5) acha o corpo ativo a interpolar. Idempotente: rodar 2× não duplica.
 */
class NotificacoesEmailTemplatesSeeder extends Seeder
{
    /** Nome amigável exibido no editor do Backoffice (CA-6), por tipo de notificação. */
    private const NOMES = [
        NotificacaoTipo::CandidaturaRecebida->value => 'E-mail — Nova candidatura recebida (contratante)',
        NotificacaoTipo::VagaEditadaMaterial->value => 'E-mail — Vaga editada (profissional)',
        NotificacaoTipo::VagaCancelada->value => 'E-mail — Vaga cancelada (profissional)',
        NotificacaoTipo::VagaEditadaMaterialCandidaturaMantida->value => 'E-mail — Candidato mantido após edição (contratante)',
        NotificacaoTipo::VagaEditadaMaterialCandidaturaRetirada->value => 'E-mail — Candidato saiu após edição (contratante)',
        // STORY-067 — eventos do turno (texto-seed v1 aprovado pelo PO em 2026-06-06).
        NotificacaoTipo::TurnoConfirmado->value => 'E-mail — Turno confirmado (profissional)',
        NotificacaoTipo::CheckinSolicitado->value => 'E-mail — Check-in aguardando validação (contratante)',
        NotificacaoTipo::TurnoAtivo->value => 'E-mail — Turno em andamento (profissional)',
        NotificacaoTipo::CheckoutSolicitado->value => 'E-mail — Check-out aguardando validação (contratante)',
        NotificacaoTipo::TurnoFinalizado->value => 'E-mail — Turno finalizado (profissional)',
        NotificacaoTipo::PixEnviado->value => 'E-mail — Pix enviado (profissional)',
        NotificacaoTipo::TurnoCancelado->value => 'E-mail — Turno cancelado (outro lado)',
        NotificacaoTipo::NoShowPro->value => 'E-mail — Turno encerrado por check-in não realizado (ambos)',
        // STORY-085 — avaliação recíproca (ADR-019): "avalie seu turno" aos dois lados.
        NotificacaoTipo::AvaliacaoPendente->value => 'E-mail — Avalie seu turno (ambos)',
    ];

    public function run(): void
    {
        $adminId = DB::table('users')->where('role', 'admin')->orderBy('id')->value('id');

        if ($adminId === null) {
            throw new RuntimeException('NotificacoesEmailTemplatesSeeder requer um admin (rode AdminUserSeeder antes).');
        }

        foreach (NotificacaoTipo::cases() as $tipo) {
            $slug = $tipo->templateSlug();

            $templateId = DB::table('templates')->where('slug', $slug)->value('id');

            if ($templateId === null) {
                // STORY-070/ADR-018: uuid gerado na aplicação (query builder não usa HasUuids).
                $templateId = (string) Str::uuid7();
                DB::table('templates')->insert([
                    'id' => $templateId,
                    'slug' => $slug,
                    'categoria' => 'email',
                    'nome_amigavel' => self::NOMES[$tipo->value],
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            // Idempotência: só carrega a v1 se o template ainda não tem nenhuma versão.
            if (DB::table('template_versoes')->where('template_id', $templateId)->exists()) {
                continue;
            }

            $conteudo = $this->carregarConteudo($slug);

            DB::table('template_versoes')->insert([
                'id' => (string) Str::uuid7(),
                'template_id' => $templateId,
                'versao' => 1,
                'conteudo' => $conteudo,
                'criado_por_admin_id' => $adminId,
                'ativa' => true,
                'created_at' => now(),
            ]);

            // Evidência de fidelidade ao texto-seed v1 do PO (STORY-053 §"Texto-seed v1").
            Log::info('notificacao.template.seeded', [
                'event' => 'notificacao.template.seeded',
                'service' => 'seed',
                'template_slug' => $slug,
                'versao' => 1,
                'content_sha256' => hash('sha256', $conteudo),
            ]);
        }
    }

    private function carregarConteudo(string $slug): string
    {
        $caminho = database_path("seeders/emails/{$slug}.md");

        if (! is_file($caminho)) {
            throw new RuntimeException("Texto-seed do template de e-mail não encontrado: {$caminho}");
        }

        $conteudo = trim((string) file_get_contents($caminho));

        if ($conteudo === '') {
            throw new RuntimeException("Texto-seed do template de e-mail está vazio: {$caminho}");
        }

        return $conteudo;
    }
}
