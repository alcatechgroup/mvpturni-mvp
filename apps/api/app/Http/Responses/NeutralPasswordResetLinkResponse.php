<?php

namespace App\Http\Responses;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Laravel\Fortify\Contracts\FailedPasswordResetLinkRequestResponse;
use Laravel\Fortify\Contracts\SuccessfulPasswordResetLinkRequestResponse;

/**
 * Resposta neutra do "Esqueci minha senha" (STORY-021 CA-7 / ADR-007 §f).
 *
 * Mesma resposta para e-mail existente, inexistente OU throttled — nunca revela se o
 * endereço está cadastrado (anti-enumeração). Ligada aos dois contratos do Fortify
 * (sucesso e falha do pedido de link) no FortifyServiceProvider.
 */
class NeutralPasswordResetLinkResponse implements FailedPasswordResetLinkRequestResponse, SuccessfulPasswordResetLinkRequestResponse
{
    public const MESSAGE = 'Se este e-mail está cadastrado, enviamos as instruções.';

    public function toResponse($request): JsonResponse|RedirectResponse
    {
        return $request->wantsJson()
            ? new JsonResponse(['message' => self::MESSAGE], 200)
            : back()->with('status', self::MESSAGE);
    }
}
