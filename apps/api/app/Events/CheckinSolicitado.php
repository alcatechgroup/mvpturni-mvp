<?php

namespace App\Events;

use Illuminate\Foundation\Events\Dispatchable;

/**
 * STORY-067 (CA-1) — PIN de check-in gerado pelo profissional (STORY-061). A 061 gravou a
 * trilha (`turno.checkin_solicitado`) mas não emitia o evento — esta classe fecha o contrato.
 * Disparado PÓS-COMMIT pelo PinCheckinService a CADA geração (re-geração = evento novo).
 *
 * `geracaoPinId` identifica a geração (UUIDv7 sorteado no service, também na trilha): é a
 * variante da chave de idempotência da estória (`checkin_solicitado:{turno}:{geracao}`) —
 * PIN novo RE-notifica o contratante; redelivery do MESMO evento não duplica (CA-3).
 */
class CheckinSolicitado
{
    use Dispatchable;

    public function __construct(
        public readonly string $turnoId,
        public readonly string $geracaoPinId,
    ) {}
}
