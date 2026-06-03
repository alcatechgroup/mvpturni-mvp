<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        // Seed mínimo da fundação (STORY-006): só o admin de teste.
        // Dados de domínio (vagas, candidaturas, etc.) entram no EPIC-001.
        $this->call(AdminUserSeeder::class);

        // STORY-017 — funções pivotais para o pré-cadastro de profissional.
        $this->call(FuncaoSeeder::class);

        // STORY-019 — cadastros pendentes para a fila de aprovação (dev/homolog; nunca prod).
        $this->call(FilaAprovacaoPendentesSeeder::class);

        // STORY-020 — catálogo de templates contratuais + versão 1 ativa (dev/homolog/prod).
        $this->call(TemplatesContratuaisSeeder::class);

        // STORY-053 — 5 corpos de e-mail de notificação como template `email` v1 ativa (CA-6, Path A).
        // Depende de AdminUserSeeder (autor da versão).
        $this->call(NotificacoesEmailTemplatesSeeder::class);

        // STORY-044 — seed mínimo de vagas do EPIC-002 (3 abertas, 1 fechada, 1 cancelada).
        $this->call(VagasSeeder::class);

        // STORY-048 — prepara o profissional de seed para o feed (função + geo + match).
        // Depende de FuncaoSeeder + VagasSeeder acima (alinha funções/geo às vagas abertas).
        $this->call(FeedSeeder::class);

        // STORY-050 — par de vagas sobrepostas para o E2E de conflito de horário.
        // Depende de FeedSeeder (profissional.teste + função primária).
        $this->call(CandidaturaConflitoSeeder::class);

        // STORY-051 — vaga do contratante.teste + 3 candidaturas ranqueadas (snapshot persistido)
        // para o E2E do painel de candidatos. Depende de AdminUserSeeder + FuncaoSeeder.
        $this->call(PainelCandidatosSeeder::class);
    }
}
