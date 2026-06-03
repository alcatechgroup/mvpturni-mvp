<?php

namespace App\Services\Notificacao;

use RuntimeException;

/**
 * STORY-053 (CA-5) — o corpo do template referenciou um `{snake_case}` que o payload da
 * notificação não tem (ou está nulo). Erro permanente (bug de template/payload), não transitório:
 * o worker NÃO envia e-mail incompleto e trata como falha — depois de 3 tentativas vira
 * `falha_envio_em` + alerta. Mesmo espírito de RenderizacaoIncompletaException (aceite, STORY-023).
 */
class TemplateEmailIncompletoException extends RuntimeException
{
    /** @param list<string> $variaveisAusentes */
    public function __construct(public readonly array $variaveisAusentes)
    {
        parent::__construct('Template de e-mail incompleto — variáveis ausentes no payload: '.implode(', ', $variaveisAusentes));
    }
}
