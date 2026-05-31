<?php

namespace App\Domain\Aceites;

/**
 * STORY-023 / ADR-010 Decisão 3A — Motor de renderização do aceite eletrônico.
 *
 * Substituição literal de placeholders `{{ns.campo}}` por valores de um mapa flat, via regex
 * própria (sem engine externa). Falha dura em placeholder ausente — o aceite nunca nasce com
 * texto incompleto. Para o aceite de ADESÃO (EPIC-001, sem turno) renderiza apenas a **Seção 1
 * (Termos gerais)** + o bloco **Assinatura eletrônica**; omite a Seção 2 (turno) e os blocos de
 * meta-autoria do template seedado (`## Histórico de validação`, `## Notas do PO`) que não fazem
 * parte do documento jurídico apresentado ao usuário.
 *
 * O EPIC-003 (aceite por turno) reutiliza `substituir()` com o documento completo (Seção 1 + 2).
 */
class AceiteRenderer
{
    /** Prefixos de heading `## ` mantidos no documento de adesão (ordem preservada do template). */
    private const SECOES_ADESAO = ['Seção 1', 'Assinatura eletrônica'];

    /**
     * Renderiza o documento de adesão (Seção 1 + Assinatura) com os dados do usuário.
     *
     * @param  array<string,string>  $contexto  mapa flat `ns.campo => valor`
     *
     * @throws PlaceholderAusenteException quando o documento mantém um placeholder sem valor
     */
    public function renderAdesao(string $conteudo, array $contexto): string
    {
        return $this->substituir($this->apenasSecoesDeAdesao($conteudo), $contexto);
    }

    /**
     * Substitui todos os `{{ns.campo}}` pelo valor correspondente. Placeholder sem valor
     * no contexto → exceção (falha dura). Não toca em texto que não seja placeholder.
     *
     * @param  array<string,string>  $contexto
     *
     * @throws PlaceholderAusenteException
     */
    public function substituir(string $documento, array $contexto): string
    {
        return preg_replace_callback('/\{\{\s*([\w.]+)\s*\}\}/', function (array $m) use ($contexto): string {
            $chave = $m[1];
            if (! array_key_exists($chave, $contexto)) {
                throw new PlaceholderAusenteException($chave);
            }

            return (string) $contexto[$chave];
        }, $documento) ?? $documento;
    }

    /**
     * Mantém o preâmbulo (título H1 + introdução antes da 1ª seção) e apenas as seções `## `
     * cujo título começa por um prefixo de {@see self::SECOES_ADESAO}. Demais seções são omitidas.
     */
    private function apenasSecoesDeAdesao(string $conteudo): string
    {
        // [preâmbulo, "## Heading1", corpo1, "## Heading2", corpo2, ...]
        $partes = preg_split('/^(##\s+.+)$/m', $conteudo, -1, PREG_SPLIT_DELIM_CAPTURE);
        if ($partes === false || $partes === []) {
            return $conteudo;
        }

        $saida = [rtrim($partes[0])];

        for ($i = 1, $n = count($partes); $i < $n; $i += 2) {
            $heading = $partes[$i];
            $corpo = $partes[$i + 1] ?? '';
            $titulo = trim((string) preg_replace('/^##\s+/', '', $heading));

            foreach (self::SECOES_ADESAO as $permitida) {
                if (str_starts_with($titulo, $permitida)) {
                    $saida[] = "\n\n".$heading.rtrim($corpo);
                    break;
                }
            }
        }

        return implode('', $saida)."\n";
    }
}
