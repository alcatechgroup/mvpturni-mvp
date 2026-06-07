<?php

namespace App\Services\Notificacao;

use App\Listeners\LinksWebApp;
use App\Models\Turno;
use App\Support\DataHora;

/**
 * STORY-067 — payload comum das notificações de turno (contrato da SCREEN-STORY-067 §2):
 * `turno_id`, `vaga_funcao`, `estabelecimento_nome` (apelido > nome > name — regra das
 * STORY-049/059/060), `turno_data_inicio` (pt-BR 24h via DataHora — DDR-002/IDR-026) e
 * `link_turno` (CTA absoluto do e-mail; o app navega pela rota interna `/turnos/{id}`).
 * Tudo PRÉ-RENDERIZADO na criação — e-mail e in-app interpolam, nunca reconsultam.
 */
final class PayloadNotificacaoTurno
{
    /** @return array<string,mixed> */
    public static function comum(Turno $turno): array
    {
        return [
            'turno_id' => $turno->id,
            'vaga_funcao' => (string) ($turno->vaga?->funcao?->nome ?? '—'),
            'estabelecimento_nome' => self::estabelecimento($turno),
            'turno_data_inicio' => DataHora::completa($turno->data_inicio),
            'link_turno' => LinksWebApp::detalheTurno($turno->id),
        ];
    }

    /** Valor do profissional formatado pt-BR ("1.234,56") — o template escreve "R$ {valor}". */
    public static function valor(Turno $turno): string
    {
        return number_format((float) $turno->valor, 2, ',', '.');
    }

    private static function estabelecimento(Turno $turno): string
    {
        $perfil = $turno->contratante?->contratanteProfile;

        return (string) ($perfil?->apelido_estabelecimento
            ?: $perfil?->nome_estabelecimento
            ?: $turno->contratante?->name
            ?: '—');
    }
}
