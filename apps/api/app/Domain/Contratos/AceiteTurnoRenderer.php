<?php

namespace App\Domain\Contratos;

/**
 * STORY-058 (CA-2, CA-4) — Motor de renderização do aceite POR TURNO (compliance.md §aceite
 * eletrônico por turno). Diferente do aceite de adesão (AceiteAdesaoRenderer, que mantém só a
 * Seção 1), o aceite do turno renderiza o documento INTEIRO (Seção 1 + Seção 2 + Assinatura),
 * descartando apenas os blocos de metadados de autoria.
 *
 * Cláusula condicional de override (PDR-002): o bloco `###` que contém o marcador
 * `{{habitualidade.override_aceito}}` na sua linha-diretiva só entra no documento quando o
 * contratante assumiu o risco da 3ª alocação PJ. A diretiva em si (instrução ao motor, em
 * itálico no template) nunca aparece no documento final. Reusa a substituição de placeholders
 * do renderer de adesão — placeholder sem valor é falha dura (nenhum aceite incompleto).
 */
class AceiteTurnoRenderer
{
    /** Cabeçalhos `## ` cujos blocos NÃO entram no aceite (metadados de autoria). */
    private const BLOCOS_OMITIDOS = ['Histórico de validação', 'Notas do PO'];

    /** Marcador da cláusula condicional de aceite de risco (PDR-002). */
    private const MARCADOR_OVERRIDE = '{{habitualidade.override_aceito}}';

    public function __construct(private readonly AceiteAdesaoRenderer $base = new AceiteAdesaoRenderer) {}

    /**
     * @param  array<string,string>  $contexto  mapa `ns.campo` => valor
     *
     * @throws RenderizacaoIncompletaException
     */
    public function renderizar(string $conteudo, array $contexto, bool $habitualidadeOverride): string
    {
        $texto = $this->extrairCorpoTurno($conteudo);
        $texto = $this->resolverClausulaOverride($texto, $habitualidadeOverride);

        return $this->base->substituir($texto, $contexto);
    }

    /** Mantém o documento inteiro (Seções 1 e 2 + Assinatura); descarta só metadados de autoria. */
    private function extrairCorpoTurno(string $conteudo): string
    {
        $blocos = preg_split('/(?=^## )/m', $conteudo) ?: [$conteudo];

        $mantidos = array_filter($blocos, function (string $bloco): bool {
            if (! str_starts_with(ltrim($bloco), '## ')) {
                return true; // preâmbulo (antes do primeiro `##`)
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
     * Resolve a cláusula condicional: sem override, o bloco `###` marcado sai inteiro; com
     * override, o bloco fica e apenas a linha-diretiva (e o separador imediato) é removida.
     */
    private function resolverClausulaOverride(string $texto, bool $override): string
    {
        if (! str_contains($texto, self::MARCADOR_OVERRIDE)) {
            return $texto; // template sem cláusula (PF) — nada a resolver
        }

        // Sub-blocos por cabeçalho ## ou ### — o bloco da cláusula termina no próximo cabeçalho.
        $blocos = preg_split('/(?=^#{2,3} )/m', $texto) ?: [$texto];

        $resolvidos = [];
        foreach ($blocos as $bloco) {
            if (! str_contains($bloco, self::MARCADOR_OVERRIDE)) {
                $resolvidos[] = $bloco;

                continue;
            }

            if (! $override) {
                continue; // contratante não assumiu risco: a cláusula não existe no documento
            }

            // Remove a linha-diretiva (parágrafo com o marcador) + um `---` imediato, se houver.
            $bloco = preg_replace('/^\*[^\n]*'.preg_quote(self::MARCADOR_OVERRIDE, '/').'[^\n]*\*\s*$\n+(?:^---\s*$\n+)?/m', '', $bloco) ?? $bloco;
            $resolvidos[] = $bloco;
        }

        return rtrim(implode('', $resolvidos))."\n";
    }
}
