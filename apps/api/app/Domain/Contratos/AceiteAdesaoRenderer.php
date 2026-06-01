<?php

namespace App\Domain\Contratos;

/**
 * STORY-023 — Motor de renderização do aceite de ADESÃO (sem turno), ADR-010 Decisão 3 + IDR-022.
 *
 * Duas etapas:
 *  1. extrairCorpoAdesao(): mantém preâmbulo + Seção 1 + Assinatura; descarta a Seção 2
 *     (turno/contratante) e os blocos de metadados de autoria (Histórico de validação,
 *     Notas do PO). Robusto a reordenação — corta por blocos de cabeçalho `## `.
 *  2. substituir(): troca `{{ns.campo}}` pelos valores do contexto; placeholder sem valor
 *     => falha dura (RenderizacaoIncompletaException). Nenhum aceite incompleto é gerado.
 */
class AceiteAdesaoRenderer
{
    /** Marcador exibido no preview no lugar dos carimbos de assinatura (IDR-022 b). */
    public const ASSINATURA_PENDENTE = '— preenchido no momento do aceite —';

    /** Cabeçalhos `## ` cujos blocos NÃO entram no aceite de adesão (prefixo, case-insensitive). */
    private const BLOCOS_OMITIDOS = ['Seção 2', 'Histórico de validação', 'Notas do PO'];

    /**
     * Renderiza o documento de adesão final.
     *
     * @param  array<string,string>  $contexto  mapa `ns.campo` => valor
     */
    public function renderizar(string $conteudo, array $contexto): string
    {
        return $this->substituir($this->extrairCorpoAdesao($conteudo), $contexto);
    }

    /** Mantém só o que é o contrato de adesão exibido/assinado pelo usuário. */
    public function extrairCorpoAdesao(string $conteudo): string
    {
        $blocos = preg_split('/(?=^## )/m', $conteudo) ?: [$conteudo];

        $mantidos = array_filter($blocos, function (string $bloco): bool {
            if (! str_starts_with(ltrim($bloco), '## ')) {
                return true; // preâmbulo (título + introdução antes do primeiro `##`)
            }

            $cabecalho = trim(substr(ltrim($bloco), 3));
            foreach (self::BLOCOS_OMITIDOS as $omitido) {
                if (stripos($cabecalho, $omitido) === 0) {
                    return false;
                }
            }

            return true;
        });

        return rtrim(implode('', $mantidos))."\n";
    }

    /**
     * @param  array<string,string>  $contexto
     *
     * @throws RenderizacaoIncompletaException
     */
    public function substituir(string $texto, array $contexto): string
    {
        $ausentes = [];

        $render = preg_replace_callback('/\{\{\s*([\w.]+)\s*\}\}/', function (array $m) use ($contexto, &$ausentes) {
            $chave = $m[1];
            if (! array_key_exists($chave, $contexto)) {
                $ausentes[] = $chave;

                return $m[0];
            }

            return $contexto[$chave];
        }, $texto) ?? $texto;

        if ($ausentes !== []) {
            throw new RenderizacaoIncompletaException(array_values(array_unique($ausentes)));
        }

        return $render;
    }
}
