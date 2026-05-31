<?php

namespace App\Domain\Aceites;

/**
 * STORY-023 / PDR-001 / CA-3 — Validação de CPF (PF) e CNPJ (MEI/PJ) por dígitos verificadores.
 *
 * Apenas formato + dígitos (sem consulta à Receita — PDR-001 exclui). Implementação própria
 * (sem lib): o algoritmo de dígito verificador é estável e trivial de testar.
 */
class DocumentoValidator
{
    /** Remove tudo que não for dígito. */
    public static function normalizar(string $documento): string
    {
        return preg_replace('/\D/', '', $documento) ?? '';
    }

    /** O tipo de documento esperado para um `tipo_pessoa` (PDR-001). */
    public static function tipoEsperado(string $tipoPessoa): string
    {
        return $tipoPessoa === 'PF' ? 'CPF' : 'CNPJ';
    }

    /** Formata para exibição no contrato: CPF `000.000.000-00`; CNPJ `00.000.000/0000-00`. */
    public static function formatar(string $documento, string $tipoPessoa): string
    {
        $d = self::normalizar($documento);

        if ($tipoPessoa === 'PF' && strlen($d) === 11) {
            return substr($d, 0, 3).'.'.substr($d, 3, 3).'.'.substr($d, 6, 3).'-'.substr($d, 9, 2);
        }

        if (strlen($d) === 14) {
            return substr($d, 0, 2).'.'.substr($d, 2, 3).'.'.substr($d, 5, 3).'/'.substr($d, 8, 4).'-'.substr($d, 12, 2);
        }

        return $d;
    }

    /** Valida o documento conforme o tipo de pessoa: PF → CPF; MEI/PJ → CNPJ. */
    public static function valido(string $documento, string $tipoPessoa): bool
    {
        return $tipoPessoa === 'PF'
            ? self::cpfValido($documento)
            : self::cnpjValido($documento);
    }

    public static function cpfValido(string $documento): bool
    {
        $cpf = self::normalizar($documento);

        if (strlen($cpf) !== 11 || preg_match('/^(\d)\1{10}$/', $cpf)) {
            return false; // tamanho errado ou todos os dígitos iguais (000..., 111...)
        }

        for ($t = 9; $t < 11; $t++) {
            $soma = 0;
            for ($i = 0; $i < $t; $i++) {
                $soma += (int) $cpf[$i] * (($t + 1) - $i);
            }
            $digito = ((10 * $soma) % 11) % 10;
            if ((int) $cpf[$t] !== $digito) {
                return false;
            }
        }

        return true;
    }

    public static function cnpjValido(string $documento): bool
    {
        $cnpj = self::normalizar($documento);

        if (strlen($cnpj) !== 14 || preg_match('/^(\d)\1{13}$/', $cnpj)) {
            return false;
        }

        $pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
        $pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

        foreach ([[12, $pesos1], [13, $pesos2]] as [$posicao, $pesos]) {
            $soma = 0;
            for ($i = 0; $i < $posicao; $i++) {
                $soma += (int) $cnpj[$i] * $pesos[$i];
            }
            $resto = $soma % 11;
            $digito = $resto < 2 ? 0 : 11 - $resto;
            if ((int) $cnpj[$posicao] !== $digito) {
                return false;
            }
        }

        return true;
    }
}
