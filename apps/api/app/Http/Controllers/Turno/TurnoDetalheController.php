<?php

namespace App\Http\Controllers\Turno;

use App\Enums\TurnoStatus;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Turno;
use App\Services\PinCheckinService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * STORY-060 — detalhe do turno (GET /api/turnos/{turno}, rota compartilhada pelos 2 papéis).
 *
 * RBAC (CA-1): profissional vê só os próprios turnos; contratante só os das próprias vagas;
 * acesso cruzado → 403 fail-secure (a UI renderiza igual ao 404 — SCREEN-060 §4.5 — para não
 * confirmar existência de turno alheio; a distinção fica no log/API).
 *
 * Visibilidade financeira por papel (CA-2 / domain/pagamento.md §Visibilidade): o payload do
 * profissional NEM CARREGA `taxa_turni`/`total_contratante` (defesa em profundidade — o filtro
 * é no servidor, não no front); o contratante recebe os 3 componentes separados.
 *
 * Timeline (CA-3): audit_logs do turno filtrados por whitelist de eventos amigáveis (a trilha
 * COMPLETA é do admin no Backoffice — compliance.md). Ordem cronológica descendente. Valores
 * nos eventos seguem a mesma visibilidade por papel (SCREEN-060 §4.1): o profissional só vê
 * dinheiro no `pix_enviado` (o valor que é dele); o contratante vê o total nos eventos de
 * pagamento.
 *
 * Aceite (CA-5): `conteudo_renderizado` do AceiteEletronicoTurno vai inline (documento
 * autocontido e imutável — ADR-010/ADR-015; o modal é somente leitura).
 */
class TurnoDetalheController extends Controller
{
    /**
     * Whitelist audit action → evento da timeline (nomes do CA-3). Ação fora do mapa não
     * aparece para as partes (ex.: `pagamento.pre_autorizacao_falhou` é operacional/admin).
     * Os eventos futuros (061/062/064/065/066) já estão mapeados — as estórias seguintes só
     * gravam o audit log e a timeline os exibe sem voltar aqui.
     */
    private const EVENTOS = [
        'turno.criado' => 'turno_criado',
        'aceite_eletronico.emitido' => 'aceite_eletronico_emitido',
        'pagamento.pre_autorizado' => 'pagamento_pre_autorizado',
        'turno.checkin_solicitado' => 'checkin_solicitado',
        'turno.checkin_validado' => 'checkin_validado',
        'turno.checkout_solicitado' => 'checkout_solicitado',
        'turno.checkout_validado' => 'checkout_validado',
        'pagamento.capturado' => 'pagamento_capturado',
        'pix.enviado' => 'pix_enviado',
        'turno.cancelado' => 'cancelado',
        'turno.no_show_pro' => 'no_show_pro',
        // STORY-066 (CA-3/CA-6) — liberação da pré-autorização (cancelamento/no-show).
        // A FALHA da liberação (`pagamento.liberacao_falhou`) fica fora da timeline das
        // partes (operacional — fila do admin; SCREEN-066 §A.5).
        'pagamento.liberado' => 'pagamento_liberado',
        // STORY-061 — cancelamento do PIN pelo profissional (aguardando_checkin→confirmado).
        'turno.checkin_cancelado' => 'checkin_cancelado',
        // STORY-062 (SCREEN-062 §4.11) — recusa pelo contratante e expiração por excesso de
        // tentativas: ambas devolvem o turno a `confirmado` e o profissional precisa entender
        // pela trilha por quê. O MOTIVO da recusa fica fora da timeline (trilha do admin).
        'turno.checkin_recusado' => 'checkin_recusado',
        'turno.checkin_pin_expirado' => 'checkin_pin_expirado',
        // STORY-064 (SCREEN-064 §4.12) — espelhos de check-out: cancelamento pelo
        // profissional, recusa pelo contratante e expiração por tentativas devolvem o
        // turno a `ativo` e a trilha explica por quê. Motivo da recusa fora da timeline.
        'turno.checkout_cancelado' => 'checkout_cancelado',
        'turno.checkout_recusado' => 'checkout_recusado',
        'turno.checkout_pin_expirado' => 'checkout_pin_expirado',
    ];

    public function show(Request $request, Turno $turno): JsonResponse
    {
        $user = $request->user();
        $souProfissional = $user !== null && $user->id === $turno->profissional_id && $user->isProfissional();
        $souContratante = $user !== null && $user->id === $turno->contratante_id && $user->isContratante();

        abort_unless($souProfissional || $souContratante, 403); // CA-1 — cruzados 403

        $turno->load(['vaga.funcao:id,nome', 'contratante.contratanteProfile', 'profissional:id,name', 'aceite']);

        $comum = [
            'id' => $turno->id,
            'funcao' => $turno->vaga?->funcao?->nome,
            'data_inicio' => $turno->data_inicio->toIso8601String(),
            'data_fim' => $turno->data_fim->toIso8601String(),
            'estado' => $turno->status->value,
            'valor' => (float) $turno->valor,
            'estabelecimento' => ['nome' => $this->nomeEstabelecimento($turno)],
            'aceite' => $turno->aceite === null ? null : [
                'emitido_em' => $turno->aceite->aceito_em?->toIso8601String(),
                'conteudo_renderizado' => $turno->aceite->conteudo_renderizado,
            ],
            'timeline' => $this->timeline($turno, $souProfissional),
        ];

        if ($souProfissional) {
            // STORY-061 (CA-1) — janela de geração do PIN: a UI decide o estado do botão
            // (antes/aberta/depois) sem hardcodar os minutos; o servidor segue validando.
            [$abre, $fecha] = PinCheckinService::janela($turno);

            return response()->json($comum + [
                'checkin_janela' => [
                    'abre_em' => $abre->toIso8601String(),
                    'fecha_em' => $fecha->toIso8601String(),
                ],
            ] + $this->pix($turno));
        }

        $contratante = [
            'taxa_turni' => (float) $turno->taxa_turni,
            'total_contratante' => (float) $turno->total_contratante,
            'profissional' => ['nome' => $turno->profissional?->name],
        ];

        // STORY-062 (CA-5) — snapshot de geofencing da geração do PIN para o card de aviso
        // da validação (SCREEN-062 §4.2). Só em `aguardando_checkin`: o aviso é do momento
        // de validar, não um atributo permanente do turno.
        if ($turno->status === TurnoStatus::AguardandoCheckin && $turno->geofencing_check_in !== null) {
            $geo = $turno->geofencing_check_in;
            $contratante['geofencing_check_in'] = [
                'ok' => (bool) ($geo['ok'] ?? false),
                'distancia_metros' => isset($geo['distancia_metros']) && $geo['distancia_metros'] !== null
                    ? (float) $geo['distancia_metros'] : null,
                'razao' => $geo['razao'] ?? null,
            ];
        }

        return response()->json($comum + $contratante);
    }

    /**
     * CA-3 — eventos do turno em ordem descendente. O `aceite_eletronico.emitido` tem
     * target próprio (AceiteEletronicoTurno) e referencia o turno via payload (ADR-018:
     * UUIDs em payload) — por isso o OR no filtro.
     *
     * @return list<array<string, mixed>>
     */
    private function timeline(Turno $turno, bool $souProfissional): array
    {
        $logs = AuditLog::query()
            ->where(fn ($q) => $q
                ->where(fn ($q) => $q->where('target_type', 'Turno')->where('target_id', $turno->id))
                ->orWhere(fn ($q) => $q
                    ->where('action', 'aceite_eletronico.emitido')
                    ->where('payload->turno_id', $turno->id)))
            ->whereIn('action', array_keys(self::EVENTOS))
            ->orderByDesc('created_at')
            ->get();

        return $logs->map(function (AuditLog $log) use ($turno, $souProfissional) {
            $evento = self::EVENTOS[$log->action];

            $item = [
                'id' => $log->id,
                'evento' => $evento,
                'ocorrido_em' => $log->created_at->toIso8601String(),
            ];

            // Visibilidade financeira na timeline (SCREEN-060 §4.1, validada pelo PO).
            if (! $souProfissional && in_array($evento, ['pagamento_pre_autorizado', 'pagamento_capturado', 'pagamento_liberado'], true)) {
                $item['valor'] = (float) $turno->total_contratante;
            }
            if ($souProfissional && $evento === 'pix_enviado') {
                $item['valor'] = (float) $turno->valor;
            }
            // Quem cancelou (STORY-066 grava `lado` no payload; tolerante à ausência).
            // Motivo visível aos DOIS lados (SCREEN-066 §A.5 — decisão do PO 2026-06-06).
            if ($evento === 'cancelado' && isset($log->payload['lado'])) {
                $item['lado'] = $log->payload['lado'];
                if (isset($log->payload['motivo']) && $log->payload['motivo'] !== null && $log->payload['motivo'] !== '') {
                    $item['motivo'] = $log->payload['motivo'];
                }
            }
            // X do no-show na copy da timeline ("em até {X} horas" — SCREEN-066 §A.5);
            // o front degrada para copy genérica quando ausente (seeds antigos).
            if ($evento === 'no_show_pro' && isset($log->payload['limite_horas'])) {
                $item['limite_horas'] = (int) $log->payload['limite_horas'];
            }
            // STORY-061 — nota de geofencing no evento de PIN (PDR-008: ambos os lados veem
            // o que foi registrado). Tolerante a seeds antigos sem o snapshot no payload.
            if ($evento === 'checkin_solicitado' && isset($log->payload['geofencing_check_in'])) {
                $geo = $log->payload['geofencing_check_in'];
                $item['geofencing'] = [
                    'ok' => (bool) ($geo['ok'] ?? false),
                    'distancia_metros' => isset($geo['distancia_metros']) && $geo['distancia_metros'] !== null
                        ? (float) $geo['distancia_metros'] : null,
                    'razao' => $geo['razao'] ?? null,
                ];
            }
            // STORY-064 (CA-7) — o evento da timeline é o ÚNICO lugar onde o geofencing
            // de check-out aparece (sem aviso destacado na UI — SCREEN-064 §4.12).
            if ($evento === 'checkout_solicitado' && isset($log->payload['geofencing_check_out'])) {
                $geo = $log->payload['geofencing_check_out'];
                $item['geofencing'] = [
                    'ok' => (bool) ($geo['ok'] ?? false),
                    'distancia_metros' => isset($geo['distancia_metros']) && $geo['distancia_metros'] !== null
                        ? (float) $geo['distancia_metros'] : null,
                    'razao' => $geo['razao'] ?? null,
                ];
            }

            return $item;
        })->values()->all();
    }

    /**
     * STORY-065 (CA-4 / SCREEN-065 §A) — status do Pix para a linha do card de valor do
     * PROFISSIONAL, só em `finalizado`. Fonte: audit `pix.enviado` (gravado pelo webhook —
     * CA-6 fonte de verdade; o timestamp exibido é o da confirmação do gateway).
     * `pix.falhou` chega como `a_caminho` (decisão §A.4 validada: PDR-010 — comunicação em
     * falha é manual da operação; a razão jamais vaza para as partes).
     *
     * @return array<string, mixed>
     */
    private function pix(Turno $turno): array
    {
        if ($turno->status !== TurnoStatus::Finalizado) {
            return [];
        }

        $enviadoEm = AuditLog::query()
            ->where('action', 'pix.enviado')
            ->where('target_type', 'Turno')
            ->where('target_id', $turno->id)
            ->value('created_at');

        return ['pix' => [
            'status' => $enviadoEm === null ? 'a_caminho' : 'enviado',
            'enviado_em' => $enviadoEm?->toIso8601String(),
        ]];
    }

    /** Mesma regra de exibição das listas (STORY-059/049): apelido > nome > name do contratante. */
    private function nomeEstabelecimento(Turno $turno): ?string
    {
        $perfil = $turno->contratante?->contratanteProfile;

        return $perfil?->apelido_estabelecimento
            ?: $perfil?->nome_estabelecimento
            ?: $turno->contratante?->name;
    }
}
