<?php

namespace App\Casts;

use Illuminate\Contracts\Database\Eloquent\CastsAttributes;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Encryption\Encrypter;
use Illuminate\Support\Facades\Log;

/**
 * STORY-065 (IDR-028) — ESPELHO do cast homônimo do app `api`: decifra a chave Pix do
 * snapshot de `pix_falhas` com o segredo DEDICADO compartilhado (`PIX_FALHA_CHAVE_KEY`),
 * distinto das APP_KEYs dos dois apps. O Backoffice só LÊ (a escrita é do worker da api);
 * o `set` existe para a factory dos testes. Manter em sincronia com o par da api.
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
            // pode derrubar a fila inteira: degrada como "sem chave" e avisa a operação.
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
        $key = (string) config('services.pix_falha.chave_key');

        if (str_starts_with($key, 'base64:')) {
            $key = base64_decode(substr($key, 7));
        }

        return new Encrypter($key, 'AES-256-CBC');
    }
}
