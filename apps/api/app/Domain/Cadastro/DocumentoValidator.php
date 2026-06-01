<?php

namespace App\Domain\Cadastro;

/**
 * STORY-023 CA-3 — Validação de documento por tipo_pessoa (PDR-001): PF → CPF,
 * MEI/PJ → CNPJ. Valida formato + dígitos verificadores. Sem consulta à Receita
 * (PDR-001). Funções puras — testáveis isoladamente (núcleo ≥98%).
 */
final class DocumentoValidator
{
    /** Mantém apenas os dígitos (remove máscara `.`, `-`, `/`, espaços). */
    public static function normalizar(string $documento): string
    {
        return preg_replace('/\D/', '', $documento) ?? '';
    }

    /** Tipo de documento esperado para o tipo de pessoa (PDR-001). */
    public static function tipoDocumento(string $tipoPessoa): string
    {
        return $tipoPessoa === 'PF' ? 'CPF' : 'CNPJ';
    }

    /** Valida o documento conforme o tipo de pessoa. */
    public static function validarParaTipoPessoa(string $tipoPessoa, string $documento): bool
    {
        return self::tipoDocumento($tipoPessoa) === 'CPF'
            ? self::cpfValido($documento)
            : self::cnpjValido($documento);
    }

    public static function cpfValido(string $documento): bool
    {
        $cpf = self::normalizar($documento);

        if (strlen($cpf) !== 11 || preg_match('/^(\d)\1{10}$/', $cpf)) {
            return false;
        }

        return self::digitoVerificador($cpf, 9, 10) === (int) $cpf[9]
            && self::digitoVerificador($cpf, 10, 11) === (int) $cpf[10];
    }

    public static function cnpjValido(string $documento): bool
    {
        $cnpj = self::normalizar($documento);

        if (strlen($cnpj) !== 14 || preg_match('/^(\d)\1{13}$/', $cnpj)) {
            return false;
        }

        $pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
        $pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

        return self::digitoPorPesos($cnpj, $pesos1) === (int) $cnpj[12]
            && self::digitoPorPesos($cnpj, $pesos2) === (int) $cnpj[13];
    }

    /** Formata o documento para exibição no contrato (CPF: 000.000.000-00; CNPJ: 00.000.000/0000-00). */
    public static function formatar(string $documento, string $tipoDocumento): string
    {
        $d = self::normalizar($documento);

        if ($tipoDocumento === 'CPF' && strlen($d) === 11) {
            return "{$d[0]}{$d[1]}{$d[2]}.{$d[3]}{$d[4]}{$d[5]}.{$d[6]}{$d[7]}{$d[8]}-{$d[9]}{$d[10]}";
        }

        if ($tipoDocumento === 'CNPJ' && strlen($d) === 14) {
            return substr($d, 0, 2).'.'.substr($d, 2, 3).'.'.substr($d, 5, 3).'/'.substr($d, 8, 4).'-'.substr($d, 12, 2);
        }

        return $d;
    }

    /** Dígito verificador do CPF a partir das posições [0, $ate) com peso inicial $pesoInicial. */
    private static function digitoVerificador(string $cpf, int $ate, int $pesoInicial): int
    {
        $soma = 0;
        for ($i = 0; $i < $ate; $i++) {
            $soma += (int) $cpf[$i] * ($pesoInicial - $i);
        }
        $resto = $soma % 11;

        return $resto < 2 ? 0 : 11 - $resto;
    }

    /** @param list<int> $pesos */
    private static function digitoPorPesos(string $cnpj, array $pesos): int
    {
        $soma = 0;
        foreach ($pesos as $i => $peso) {
            $soma += (int) $cnpj[$i] * $peso;
        }
        $resto = $soma % 11;

        return $resto < 2 ? 0 : 11 - $resto;
    }
}
