<?php

namespace App\Services\Notificacao;

use App\Enums\NotificacaoTipo;
use App\Models\Notificacao;
use App\Models\Turno;

/**
 * STORY-067 (CA-1/2/3) — ponto comum dos 8 listeners de turno: monta o payload (comum + extras
 * da SCREEN-STORY-067 §2), resolve a chave de idempotência e delega ao CriarNotificacaoService
 * da 053 (linha em `notificacoes` + audit `notificacao.criada` + job de e-mail na fila).
 *
 * Chaves (CA-3): `{tipo}:{turno_id}` por padrão; `{tipo}:{turno_id}:{geracao_pin_id}` para
 * checkin/checkout (re-geração de PIN re-notifica); `no_show_pro:{turno_id}:{destinatario_id}`
 * porque o no-show notifica AMBOS os lados (uma linha por destinatário — a UNIQUE exige sufixo).
 */
class NotificarEventoTurnoService
{
    public function __construct(private readonly CriarNotificacaoService $criar) {}

    /**
     * Carrega o agregado a partir do id do evento; null = referência desconhecida
     * (defensivo — não derruba o worker, mesmo racional do HandlePixEnviado/065).
     */
    public function turno(string $turnoId): ?Turno
    {
        return Turno::query()
            ->with(['vaga.funcao', 'profissional', 'contratante.contratanteProfile'])
            ->find($turnoId);
    }

    /** @param array<string,mixed> $extras */
    public function notificar(
        Turno $turno,
        NotificacaoTipo $tipo,
        string $destinatarioId,
        array $extras = [],
        ?string $sufixoChave = null,
    ): Notificacao {
        $chave = "{$tipo->value}:{$turno->id}".($sufixoChave !== null ? ":{$sufixoChave}" : '');

        return $this->criar->criar(
            tipo: $tipo,
            destinatarioId: $destinatarioId,
            vagaId: $turno->vaga_id,
            candidaturaId: $turno->candidatura_id,
            payload: PayloadNotificacaoTurno::comum($turno) + $extras,
            idempotencyKey: $chave,
        );
    }
}
