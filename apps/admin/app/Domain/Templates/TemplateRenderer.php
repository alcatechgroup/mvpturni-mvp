<?php

namespace App\Domain\Templates;

use Illuminate\Support\Str;

/**
 * STORY-020 — Renderização do conteúdo do template para a UI do Backoffice (CA-3/CA-4).
 *
 * Markdown → HTML **seguro** (raw HTML do admin é descartado: sem template injection, sem
 * execução de código — §4 segurança / ADR-010) e os placeholders `{{ns.campo}}` são mantidos
 * visíveis como "chips" (`⟦ns.campo⟧`), destacando em vermelho os que estão fora da lista
 * canônica. Não substitui placeholders por dados — isso é a renderização do aceite (STORY-023/024).
 */
class TemplateRenderer
{
    /**
     * @param  list<string>  $invalidos  placeholders a marcar como inválidos (tom de erro)
     */
    public function html(string $conteudo, array $invalidos = []): string
    {
        // html_input=strip remove qualquer HTML que o admin tenha digitado — o template é
        // texto jurídico renderizado, nunca código executável.
        $html = Str::markdown($conteudo, [
            'html_input' => 'strip',
            'allow_unsafe_links' => false,
        ]);

        return $this->destacarPlaceholders($html, $invalidos);
    }

    /** @param list<string> $invalidos */
    private function destacarPlaceholders(string $html, array $invalidos): string
    {
        return preg_replace_callback('/\{\{\s*([\w.]+)\s*\}\}/', function (array $m) use ($invalidos) {
            $nome = $m[1];
            $bad = in_array($nome, $invalidos, true);
            $classe = $bad ? 'ph ph-bad' : 'ph';
            $titulo = $bad ? ' title="placeholder inválido"' : '';

            return '<span class="'.$classe.'"'.$titulo.'>⟦'.e($nome).'⟧</span>';
        }, $html) ?? $html;
    }
}
