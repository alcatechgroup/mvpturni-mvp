<?php

namespace App\Services;

use App\Domain\Vaga\EdicaoMaterial;
use App\Domain\Vaga\EditarVagaResultado;
use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Events\VagaEditadaMaterialmente;
use App\Models\AuditLog;
use App\Models\Candidatura;
use App\Models\User;
use App\Models\Vaga;
use App\Models\VagaVersao;
use DomainException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * STORY-052 / PDR-009 — edição material da vaga, atômica. Dado o payload validado:
 *
 *  - **não material** (nenhum dos 6 campos materiais diferiu): UPDATE in-place, sem snapshot,
 *    sem evento, sem transição de candidatura (CA-5).
 *  - **material sem candidatos pendentes**: snapshot da nova versão + UPDATE (CA-4) — não há
 *    quem notificar.
 *  - **material com candidatos pendentes** (`pendente` ou `pendente_revisao_apos_edicao`): em UMA
 *    transação — INSERT `vaga_versoes` da nova versão + UPDATE `vagas` + transição
 *    `pendente → pendente_revisao_apos_edicao` (carimbando `revisao_prazo_em` = 24h ou início do
 *    turno, o que vier antes — PDR-009) **sem tocar** quem já estava em revisão + audit
 *    `vaga.editada_materialmente` + evento `VagaEditadaMaterialmente` (CA-3).
 *
 * Versionamento: cada `vaga_versoes[versao=N]` é o estado material enquanto `versao_atual==N`
 * (consistente com PublicarVagaService, que grava a v1). A edição material cria a v(N+1) com os
 * novos valores; as candidaturas **mantêm** o `vaga_versao_id` da versão que viram, então o diff
 * do profissional é "o que viu → estado atual". A localização é material (PDR-009) mas deriva do
 * perfil (ADR-013), não é editável aqui — fica fora do payload e do diff.
 *
 * RBAC (papel + dono) e estado editável são do controller; aqui só executa. Vaga fora de `aberta`
 * lança DomainException (o controller traduz em 409).
 *
 * @throws DomainException quando a vaga não está `aberta` (fail-closed).
 */
class EditarVagaService
{
    /** Estados de candidatura que contam como "candidato pendente a notificar" (CA-3). */
    private const PENDENTES = [
        CandidaturaEstado::Pendente,
        CandidaturaEstado::PendenteRevisaoAposEdicao,
    ];

    /**
     * @param  array{funcao_id:int,data_inicio:string,data_fim:string,valor:float|string,posicoes:int,observacoes?:?string}  $dados
     */
    public function editar(User $contratante, Vaga $vaga, array $dados): EditarVagaResultado
    {
        if ($vaga->estado !== VagaEstado::Aberta) {
            // Vaga fechada/cancelada não é editável (fora de escopo da estória → 409 no controller).
            throw new DomainException('Vaga não editável: estado '.$vaga->estado->value);
        }

        $antes = EdicaoMaterial::snapshotDeVaga($vaga);
        $depois = EdicaoMaterial::snapshotDePayload($dados);
        $diff = EdicaoMaterial::diff($antes, $depois);

        // CA-5 — edição não material: UPDATE direto, sem snapshot/evento/revisão.
        if ($diff === []) {
            $vaga->fill($this->camposEditaveis($dados))->save();

            return new EditarVagaResultado($vaga, material: false, diff: [], candidatosNotificadosIds: []);
        }

        return DB::transaction(function () use ($contratante, $vaga, $dados, $diff) {
            $novaVersao = $vaga->versao_atual + 1;

            // CA-3/CA-6 — snapshot imutável (trigger Postgres STORY-044) da NOVA versão. Mesma
            // forma da v1 do PublicarVagaService; lat/lng inalterados (localização não é editável).
            VagaVersao::create([
                'vaga_id' => $vaga->id,
                'versao' => $novaVersao,
                'snapshot' => [
                    'funcao_id' => (int) $dados['funcao_id'],
                    'data_inicio' => Carbon::parse($dados['data_inicio'])->toIso8601String(),
                    'data_fim' => Carbon::parse($dados['data_fim'])->toIso8601String(),
                    'valor' => (float) $dados['valor'],
                    'posicoes' => (int) $dados['posicoes'],
                    'observacoes' => $this->observacoes($dados),
                    'lat' => $vaga->lat !== null ? (float) $vaga->lat : null,
                    'lng' => $vaga->lng !== null ? (float) $vaga->lng : null,
                ],
                'editado_por' => $contratante->id,
            ]);

            $vaga->fill($this->camposEditaveis($dados));
            $vaga->versao_atual = $novaVersao;
            $vaga->save();

            // Prazo de revisão (PDR-009): 24h a partir de agora OU o início do turno (já com o
            // novo valor), o que vier antes. O cron de auto-retirada lê este carimbo (CA-9).
            $prazo = Carbon::now()->addDay();
            if ($vaga->data_inicio->lt($prazo)) {
                $prazo = $vaga->data_inicio->copy();
            }

            // CA-3 — só candidaturas `pendente` transitam; as que já estavam em revisão não são
            // tocadas (mantêm prazo e a versão que viram). Lock para evitar corrida com o cron.
            $candidaturas = Candidatura::query()
                ->where('vaga_id', $vaga->id)
                ->where('estado', CandidaturaEstado::Pendente)
                ->lockForUpdate()
                ->get();

            $notificadosIds = [];
            foreach ($candidaturas as $candidatura) {
                $candidatura->revisao_prazo_em = $prazo;
                $candidatura->transitionTo(CandidaturaEstado::PendenteRevisaoAposEdicao);
                $notificadosIds[] = $candidatura->id;
            }

            // Quantos candidatos vivos a edição afeta (inclui quem já estava em revisão — CA-3).
            $totalPendentes = Candidatura::query()
                ->where('vaga_id', $vaga->id)
                ->whereIn('estado', self::PENDENTES)
                ->count();

            AuditLog::create([
                'actor_id' => $contratante->id,
                'action' => 'vaga.editada_materialmente',
                'target_type' => 'Vaga',
                'target_id' => $vaga->id,
                'payload' => [
                    'versao' => $novaVersao,
                    'campos' => array_map(fn ($m) => $m['campo'], $diff),
                    'candidatos_notificados' => count($notificadosIds),
                    'candidatos_pendentes' => $totalPendentes,
                ],
                'ip' => request()->ip(),
                'user_agent' => request()->userAgent(),
            ]);

            // Notificação real é da STORY-053 (consome este evento). Só disparamos quando há
            // alguém recém-movido para revisão — nada a notificar, nada a disparar.
            if ($notificadosIds !== []) {
                VagaEditadaMaterialmente::dispatch($vaga, $diff, $notificadosIds);
            }

            Log::info('vaga.editada_materialmente', [
                'event' => 'vaga.editada_materialmente',
                'vaga_id' => $vaga->id,
                'contratante_id' => $contratante->id,
                'versao' => $novaVersao,
                'campos' => array_map(fn ($m) => $m['campo'], $diff),
                'candidatos_notificados' => count($notificadosIds),
            ]);

            return new EditarVagaResultado(
                $vaga,
                material: true,
                diff: $diff,
                candidatosNotificadosIds: $notificadosIds,
            );
        });
    }

    /** Os 6 campos materiais editáveis prontos para `Vaga::fill` (localização fica de fora). */
    private function camposEditaveis(array $dados): array
    {
        return [
            'funcao_id' => $dados['funcao_id'],
            'data_inicio' => $dados['data_inicio'],
            'data_fim' => $dados['data_fim'],
            'valor' => $dados['valor'],
            'posicoes' => $dados['posicoes'],
            'observacoes' => $this->observacoes($dados),
        ];
    }

    private function observacoes(array $dados): ?string
    {
        $obs = $dados['observacoes'] ?? null;
        if ($obs === null) {
            return null;
        }
        $t = trim((string) $obs);

        return $t === '' ? null : $t;
    }
}
