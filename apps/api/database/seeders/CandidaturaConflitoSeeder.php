<?php

namespace Database\Seeders;

use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Models\Candidatura;
use App\Models\Funcao;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use Illuminate\Database\Seeder;

/**
 * STORY-050 (CA-11) — par de vagas que se SOBREPÕEM no tempo, para o E2E de conflito de horário.
 *
 * O VagasSeeder cria as 3 vagas abertas em dias distintos (sem sobreposição), então não há como
 * o E2E reproduzir o gate de conflito com elas. Aqui criamos DUAS vagas abertas na MESMA janela
 * (mesmo dia/horário, ~30 dias à frente), ambas na FUNÇÃO PRIMÁRIA do `profissional.teste`
 * (logo, alto-match e visíveis no feed) e na geo dele (distância ~0). Valores distintivos
 * (R$ 991 e R$ 992) permitem ao E2E achar cada card pelo texto do valor de forma determinística.
 *
 * Idempotente: não recria se o par já existe (marcado por `observacoes`). Roda DEPOIS de
 * FeedSeeder (precisa do profissional.teste e da função primária). DEV/HOMOLOG — inócuo em prod
 * (o profissional.teste não existe lá).
 */
class CandidaturaConflitoSeeder extends Seeder
{
    private const MARCADOR_A = 'e2e-conflito-A';

    private const MARCADOR_B = 'e2e-conflito-B';

    public function run(): void
    {
        $profissional = User::where('email', 'profissional.teste@turni.local')->first();
        if ($profissional === null) {
            return;
        }

        $contratante = User::where('email', 'contratante.seed@turni.local')->first();
        $funcaoPrimaria = Funcao::query()->orderBy('id')->value('id');
        if ($contratante === null || $funcaoPrimaria === null) {
            return;
        }

        // Janela única compartilhada → as duas se sobrepõem (gate de conflito dispara).
        $inicio = now()->addDays(30)->setTime(18, 0);
        $fim = (clone $inicio)->setTime(23, 0);

        $vagaA = $this->criarVaga($contratante->id, $funcaoPrimaria, $inicio, $fim, 991.00, self::MARCADOR_A);
        $this->criarVaga($contratante->id, $funcaoPrimaria, $inicio, $fim, 992.00, self::MARCADOR_B);

        // Pré-condição do E2E de conflito: o profissional JÁ tem candidatura pendente na vaga A.
        // Assim o teste abre só a vaga B (992) e candidata → gate `conflito_horario` dispara,
        // SEM depender de navegar entre duas telas de detalhe no mesmo teste. Idempotente.
        $jaTem = Candidatura::where('profissional_id', $profissional->id)
            ->where('vaga_id', $vagaA->id)
            ->exists();
        if (! $jaTem) {
            Candidatura::create([
                'vaga_id' => $vagaA->id,
                'profissional_id' => $profissional->id,
                'estado' => CandidaturaEstado::Pendente,
                'vaga_versao_id' => $vagaA->versoes()->value('id'),
                'score_no_momento' => 85,
            ]);
        }
    }

    private function criarVaga(string $contratanteId, string $funcaoId, $inicio, $fim, float $valor, string $marcador): Vaga
    {
        // Idempotente: reusa a vaga marcada se já existe (não recria a cada `db:seed`).
        $existente = Vaga::where('observacoes', $marcador)->first();
        if ($existente !== null) {
            return $existente;
        }

        $vaga = Vaga::create([
            'contratante_id' => $contratanteId,
            'funcao_id' => $funcaoId,
            'data_inicio' => $inicio,
            'data_fim' => $fim,
            'valor' => $valor,
            'posicoes' => 1,
            'posicoes_preenchidas' => 0,
            'observacoes' => $marcador,
            // Mesma geo do profissional.teste (FeedSeeder) → distância ~0, alto-match.
            'lat' => -23.55,
            'lng' => -46.63,
            'cidade' => 'São Paulo',
            'uf' => 'SP',
            'estado' => VagaEstado::Aberta,
            'versao_atual' => 1,
            'publicada_em' => now(),
        ]);

        VagaVersao::create([
            'vaga_id' => $vaga->id,
            'versao' => 1,
            'snapshot' => [
                'funcao_id' => $vaga->funcao_id,
                'data_inicio' => $vaga->data_inicio->toIso8601String(),
                'data_fim' => $vaga->data_fim->toIso8601String(),
                'valor' => (float) $vaga->valor,
                'posicoes' => $vaga->posicoes,
                'observacoes' => $vaga->observacoes,
                'lat' => (float) $vaga->lat,
                'lng' => (float) $vaga->lng,
            ],
            'editado_por' => $contratanteId,
        ]);

        return $vaga;
    }
}
