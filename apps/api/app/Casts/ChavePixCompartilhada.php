<?php

namespace App\Casts;

use Illuminate\Contracts\Database\Eloquent\CastsAttributes;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Encryption\Encrypter;
use Illuminate\Support\Facades\Log;

/**
 * STORY-065 (IDR-028) — criptografia da chave Pix do snapshot de `pix_falhas` com segredo
 * DEDICADO e COMPARTILHADO entre `api` e `admin` (`PIX_FALHA_CHAVE_KEY`).
 *
 * Por quê não o cast `encrypted` nativo: ele usa a APP_KEY, e cada app tem a sua (correto —
 * vazamento de uma não compromete a outra). O Backoffice precisa LER a chave para o
 * tratamento manual do Pix (CA-5/PDR-010), então este campo usa um segredo próprio,
 * distinto das duas APP_KEYs (espírito da ADR-009 Decisão 5A: chave de dados ≠ APP_KEY).
 * Classe ESPELHADA no app admin — manter as duas em sincronia.
 */
class ChavePixCompartilhada implements CastsAttributes
{
    public function get(Model $model, string $key, mixed $value, array $attributes): ?string
    {
        if ($value === null) {
            return null;
        }

        try {
            return self::encrypter()->decryptString($value);
        } catch (DecryptException) {
            // Linha cifrada com OUTRO segredo (ex.: seed que rodou sem a env — rc.77) não
            // pode derrubar quem lê: degrada como "sem chave" e avisa a operação.
            Log::warning('pix_falha.chave_indecifravel', ['pix_falha_id' => $model->getKey()]);

            return null;
        }
    }

    public function set(Model $model, string $key, mixed $value, array $attributes): ?string
    {
        return $value === null ? null : self::encrypter()->encryptString($value);
    }

    private static function encrypter(): Encrypter
    {
        $key = (string) config('services.pagarme.pix_falha_chave_key');

        if (str_starts_with($key, 'base64:')) {
            $key = base64_decode(substr($key, 7));
        }

        return new Encrypter($key, 'AES-256-CBC');
    }
}
