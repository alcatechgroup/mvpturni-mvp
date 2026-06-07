<?php

namespace App\Services;

use App\Domain\Cadastro\DocumentoValidator;
use App\Domain\Contratos\AceiteTurnoRenderer;
use App\Domain\Contratos\TemplateIndisponivelException;
use App\Domain\Turno\AprovarCandidaturaResultado;
use App\Domain\Turno\GateHabitualidadeAceite;
use App\Domain\Turno\HabitualidadeAceite;
use App\Enums\CandidaturaEstado;
use App\Enums\VagaEstado;
use App\Events\TurnoCriado;
use App\Jobs\PreAutorizarTurnoJob;
use App\Models\AceiteEletronicoTurno;
use App\Models\AuditLog;
use App\Models\Candidatura;
use App\Models\Template;
use App\Models\TemplateVersao;
use App\Models\Turno;
use App\Models\User;
use App\Models\Vaga;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * STORY-058 — aprova a candidatura (contratante dono — decisão PO 2026-06-04) e ABRE o turno:
 * em transação Postgres, aplica a habitualidade do aceite (PDR-002 sobre turnos — ADR-006/015),
 * cria o Turno `confirmado` com o financeiro congelado (taxa 15% — PDR-004), transita a
 * candidatura → `aprovada`, preenche a posição da vaga (fecha na última — domain/vaga.md),
 * emite o AceiteEletronicoTurno imutável (TemplateVersao ativa do tipo de pessoa; cláusula de
 * risco quando override PJ — compliance.md) e grava a trilha de auditoria (CA-7). Após o commit,
 * despacha a pré-autorização assíncrona (PreAutorizarTurnoJob — ADR-002/ADR-016).
 *
 * Idempotência de clique-duplo (CA-5): candidatura `aprovada` → 409 com o turno existente; a
 * UNIQUE(candidatura_id) de `turnos` (ADR-015) é a barreira dura contra a corrida.
 *
 * A autorização (papel contratante + dono da vaga) é do controller. Aqui só decide e cria.
 */
class AprovarCandidaturaService
{
    /** Taxa Turni sobre o valor do turno (PDR-004 — não é decisão desta estória). */
    private const TAXA_PERCENT = 15;

    public function __construct(
        private readonly Request $request,
        private readonly GateHabitualidadeAceite $gateHabitualidade,
        private readonly AceiteTurnoRenderer $renderer,
    ) {}

    public function aprovar(User $contratante, Candidatura $candidatura, bool $override): AprovarCandidaturaResultado
    {
        // CA-5 — clique duplo/double-submit: aprovada de novo devolve o turno existente (409).
        if ($candidatura->estado === CandidaturaEstado::Aprovada) {
            $turnoId = Turno::where('candidatura_id', $candidatura->id)->value('id');

            return AprovarCandidaturaResultado::jaAprovada((string) $turnoId);
        }

        if ($candidatura->estado !== CandidaturaEstado::Pendente) {
            return AprovarCandidaturaResultado::bloqueada(
                'candidatura_invalida',
                'Esta candidatura não está mais disponível para aceite.',
            );
        }

        $vaga = $candidatura->vaga;
        if ($vaga->estado !== VagaEstado::Aberta || $vaga->data_inicio->isPast()) {
            return AprovarCandidaturaResultado::bloqueada(
                'vaga_fechada',
                'Esta vaga não está mais aberta.',
            );
        }

        // PDR-002 — habitualidade do aceite, contada sobre turnos (CA-3/CA-4).
        $profissional = $candidatura->profissional;
        $habitualidade = $this->gateHabitualidade->verificar($profissional, $vaga);

        if ($habitualidade === HabitualidadeAceite::BloqueadoPf) {
            return AprovarCandidaturaResultado::bloqueada(
                'habitualidade_bloqueio',
                'este profissional é PF e já tem 2 alocações nesta semana neste estabelecimento; bloqueado por PDR-002',
            );
        }

        if ($habitualidade === HabitualidadeAceite::RequerOverride && ! $override) {
            return AprovarCandidaturaResultado::bloqueada(
                'requer_override',
                'este profissional já tem 2 alocações nesta semana; clique "Assumo o risco e aceito" para continuar (registrado no AceiteEletronico)',
            );
        }

        // O override só é carimbado quando há risco real (3ª alocação PJ) — não basta enviá-lo.
        $overrideAceito = $habitualidade === HabitualidadeAceite::RequerOverride && $override;

        [$valor, $taxa, $total] = $this->financeiro((string) $vaga->valor);

        $versao = $this->versaoAtiva($profissional);
        $aceitoEm = CarbonImmutable::now();
        $ip = (string) $this->request->ip();
        $fingerprint = hash('sha256', $this->request->userAgent().':'.$ip.':'.$aceitoEm->format('Y-m-d'));

        $contexto = $this->contexto($contratante, $profissional, $vaga, $valor, $taxa, $total, $aceitoEm, $ip, $fingerprint, $overrideAceito);

        // Renderiza ANTES da transação: placeholder ausente => falha dura, sem efeitos colaterais.
        $conteudoRenderizado = $this->renderer->renderizar($versao->conteudo, $contexto, $overrideAceito);

        $turno = DB::transaction(function () use (
            $contratante, $candidatura, $vaga, $valor, $taxa, $total, $versao,
            $conteudoRenderizado, $contexto, $aceitoEm, $ip, $fingerprint, $overrideAceito
        ) {
            $turno = Turno::create([
                'candidatura_id' => $candidatura->id,
                'vaga_id' => $vaga->id,
                'vaga_versao_id' => $candidatura->vaga_versao_id,
                'profissional_id' => $candidatura->profissional_id,
                'contratante_id' => $vaga->contratante_id,
                'estabelecimento_id' => $vaga->contratante_id, // MVP: estabelecimento = contratante
                'status' => 'confirmado',
                'valor' => $valor,
                'taxa_turni' => $taxa,
                'total_contratante' => $total,
                'data_inicio' => $vaga->data_inicio,
                'data_fim' => $vaga->data_fim,
            ]);

            $candidatura->transitionTo(CandidaturaEstado::Aprovada);
            $vaga->preencherPosicao(); // fecha a vaga ao preencher a última posição

            $aceite = AceiteEletronicoTurno::create([
                'turno_id' => $turno->id,
                'template_versao_id' => $versao->id,
                'conteudo_renderizado' => $conteudoRenderizado,
                'dados_renderizados' => $contexto,
                'aceito_em' => $aceitoEm,
                'ip' => $ip,
                'fingerprint' => $fingerprint,
                'habitualidade_override' => $overrideAceito,
            ]);

            // CA-7 — trilha imutável (audit_logs, trigger + REVOKE herdados).
            AuditLog::create([
                'actor_id' => $contratante->id,
                'action' => 'turno.criado',
                'target_type' => 'Turno',
                'target_id' => $turno->id,
                'payload' => [
                    'candidatura_id' => $candidatura->id,
                    'vaga_id' => $vaga->id,
                    'total_contratante' => $total,
                    'habitualidade_override' => $overrideAceito,
                ],
                'ip' => $ip,
                'user_agent' => $this->request->userAgent(),
            ]);
            AuditLog::create([
                'actor_id' => $contratante->id,
                'action' => 'aceite_eletronico.emitido',
                'target_type' => 'AceiteEletronicoTurno',
                'target_id' => $aceite->id,
                'payload' => [
                    'turno_id' => $turno->id,
                    'template_versao_id' => $versao->id,
                    'habitualidade_override' => $overrideAceito,
                ],
                'ip' => $ip,
                'user_agent' => $this->request->userAgent(),
            ]);

            return $turno;
        });

        // CA-6 — pré-autorização assíncrona, só depois do commit (nada de job para turno fantasma).
        PreAutorizarTurnoJob::dispatch($turno->id)->afterCommit();

        // STORY-067 (CA-1) — pós-commit: notificação `turno_confirmado` ao profissional.
        TurnoCriado::dispatch($turno->id);

        return AprovarCandidaturaResultado::aprovada($turno);
    }

    /**
     * Preview do financeiro de uma vaga (PDR-004) — usado também pelo painel (SCREEN-058 D1).
     *
     * @return array{0:string,1:string,2:string} [valor, taxa, total] em string decimal "123.45"
     */
    public static function financeiro(string $valorDecimal): array
    {
        // Aritmética em centavos inteiros (sem float/bcmath) — espelha PagarmeGateway::centavos().
        $partes = explode('.', trim($valorDecimal), 2);
        $valorCents = ((int) $partes[0]) * 100 + (int) str_pad(substr($partes[1] ?? '', 0, 2), 2, '0');

        $taxaCents = intdiv($valorCents * self::TAXA_PERCENT + 50, 100); // 15%, meio-arredonda p/ cima
        $totalCents = $valorCents + $taxaCents;

        $fmt = fn (int $c): string => sprintf('%d.%02d', intdiv($c, 100), $c % 100);

        return [$fmt($valorCents), $fmt($taxaCents), $fmt($totalCents)];
    }

    /** Versão ativa do template contratual do tipo de pessoa (PF → autônomo; MEI/PJ → B2B). */
    private function versaoAtiva(User $profissional): TemplateVersao
    {
        $tipo = strtoupper((string) ($profissional->profissionalProfile?->tipo_pessoa ?? 'PF'));
        $slug = $tipo === 'PF' ? 'pf_autonomo_eventual' : 'mei_pj_b2b';

        $versao = Template::where('slug', $slug)->first()?->versaoAtiva;

        if (! $versao) {
            throw new TemplateIndisponivelException($slug);
        }

        return $versao;
    }

    /**
     * Placeholders do aceite por turno (compliance.md §placeholders).
     *
     * @return array<string,string>
     */
    private function contexto(
        User $contratante,
        User $profissional,
        Vaga $vaga,
        string $valor,
        string $taxa,
        string $total,
        CarbonImmutable $aceitoEm,
        string $ip,
        string $fingerprint,
        bool $overrideAceito,
    ): array {
        $perfilProf = $profissional->profissionalProfile;
        $perfilContr = $contratante->contratanteProfile;

        $tipoDoc = DocumentoValidator::tipoDocumento(strtoupper((string) ($perfilProf?->tipo_pessoa ?? 'PF')));
        $documento = $perfilProf?->documento_encrypted
            ? DocumentoValidator::formatar((string) $perfilProf->documento_encrypted, $tipoDoc)
            : '—';

        $reais = fn (string $v): string => 'R$ '.number_format((float) $v, 2, ',', '.');

        return [
            'contratante.razao_social' => (string) ($perfilContr?->nome_estabelecimento ?? $contratante->name),
            'contratante.cnpj' => $perfilContr?->cnpj_encrypted
                ? DocumentoValidator::formatar((string) $perfilContr->cnpj_encrypted, 'CNPJ')
                : '—',
            'contratante.endereco_completo' => (string) ($perfilContr?->endereco_completo ?? $perfilContr?->cidade ?? '—'),
            'profissional.nome' => $profissional->name,
            'profissional.documento' => $documento,
            'profissional.endereco_completo' => trim("{$perfilProf?->bairro}, {$perfilProf?->cidade}", ', ') ?: '—',
            'turno.funcao' => (string) ($vaga->funcao?->nome ?? '—'),
            'turno.data_inicio' => $vaga->data_inicio->format('d/m/Y H:i'),
            'turno.data_fim' => $vaga->data_fim->format('d/m/Y H:i'),
            'turno.valor' => $reais($valor),
            'turno.taxa_turni' => $reais($taxa),
            'turno.total_contratante' => $reais($total),
            'aceite.timestamp' => $aceitoEm->format('d/m/Y H:i'),
            'aceite.ip' => $ip,
            'aceite.fingerprint' => $fingerprint,
            'habitualidade.override_aceito' => $overrideAceito ? 'true' : 'false',
        ];
    }
}
