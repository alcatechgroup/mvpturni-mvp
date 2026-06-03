<?php

namespace App\Services\Notificacao;

/**
 * STORY-053 (CA-5/CA-6, Path A) — renderiza o corpo editável de um e-mail de notificação.
 *
 * O `conteudo` da `TemplateVersao` ativa segue o formato escolhido para a categoria `email`:
 * um front-matter `chave: valor` (preheader/h1/cta_label/cta_url/aviso), um separador `---`, e os
 * parágrafos em texto abaixo. Tudo interpolado com o `payload` da notificação via `{snake_case}`.
 *
 * O resultado é o MESMO array que o layout de e-mail de STORY-021
 * (`resources/views/emails/transacional*.blade.php`) consome — paridade HTML/text de graça. A
 * saudação vem do nome do destinatário (convenção do TransacionalMail) e o rodapé é fixo (story
 * §"Convenções comuns") — só o corpo variável é editável no Backoffice.
 *
 * Placeholder sem valor no payload => exceção (TemplateEmailIncompletoException): nunca enviamos
 * e-mail pela metade. Mesma garantia de AceiteAdesaoRenderer::substituir (aceite).
 */
class EmailTemplateRenderer
{
    /** Rodapé curto comum a todos os e-mails de notificação (STORY-053 §"Convenções comuns"). */
    private const RODAPE = 'Você recebeu este e-mail porque é parte do funil ativo de uma vaga no Turni. '
        .'Dúvidas: contato@turni.com.br · Política de privacidade.';

    /**
     * @param  array<string,mixed>  $payload
     * @return array<string,mixed>
     *
     * @throws TemplateEmailIncompletoException
     */
    public function renderizar(string $conteudo, array $payload, ?string $nomeDestinatario): array
    {
        [$frontMatter, $corpo] = $this->separar($conteudo);

        $ausentes = [];
        $interpolar = $this->interpolador($payload, $ausentes);

        $h1 = $interpolar($frontMatter['h1'] ?? '');
        $preheader = $interpolar($frontMatter['preheader'] ?? '');
        $ctaLabel = $interpolar($frontMatter['cta_label'] ?? '');
        $ctaUrl = $interpolar($frontMatter['cta_url'] ?? '');
        $avisoRaw = trim($frontMatter['aviso'] ?? '');
        $aviso = $avisoRaw === '' ? null : $interpolar($avisoRaw);

        $corpoInterpolado = $interpolar($corpo);

        if ($ausentes !== []) {
            throw new TemplateEmailIncompletoException(array_values(array_unique($ausentes)));
        }

        return [
            'preheader' => $preheader,
            'h1' => $h1,
            'saudacao' => $this->saudacao($nomeDestinatario),
            // Cada linha não-vazia vira um parágrafo: o `{diff_texto}` multi-linha (template 2)
            // expande em uma linha legível por campo alterado.
            'paragrafos' => $this->paragrafos($corpoInterpolado),
            'ctaLabel' => $ctaLabel,
            'ctaUrl' => $ctaUrl,
            'aviso' => $aviso,
            'rodape' => self::RODAPE,
        ];
    }

    /**
     * @param  array<string,mixed>  $payload
     * @param  list<string>  $ausentes  acumula (por referência) as chaves sem valor
     */
    private function interpolador(array $payload, array &$ausentes): callable
    {
        return function (string $texto) use ($payload, &$ausentes): string {
            return preg_replace_callback('/\{([a-z0-9_]+)\}/', function (array $m) use ($payload, &$ausentes) {
                $chave = $m[1];
                if (! array_key_exists($chave, $payload) || $payload[$chave] === null || $payload[$chave] === '') {
                    $ausentes[] = $chave;

                    return $m[0];
                }

                return (string) $payload[$chave];
            }, $texto) ?? $texto;
        };
    }

    private function saudacao(?string $nome): string
    {
        $nome = trim((string) $nome);

        return $nome === '' ? 'Olá.' : "Olá, {$nome}.";
    }

    /** @return list<string> */
    private function paragrafos(string $corpo): array
    {
        $linhas = preg_split('/\r\n|\r|\n/', $corpo) ?: [];

        return array_values(array_filter(
            array_map('trim', $linhas),
            fn (string $linha): bool => $linha !== '',
        ));
    }

    /**
     * Separa o front-matter (antes do `---`) do corpo. Sem separador, tudo é corpo.
     *
     * @return array{0: array<string,string>, 1: string}
     */
    private function separar(string $conteudo): array
    {
        $linhas = preg_split('/\r\n|\r|\n/', $conteudo) ?: [];

        $sep = null;
        foreach ($linhas as $i => $linha) {
            if (trim($linha) === '---') {
                $sep = $i;
                break;
            }
        }

        if ($sep === null) {
            return [[], trim($conteudo)];
        }

        $frontMatter = [];
        foreach (array_slice($linhas, 0, $sep) as $linha) {
            if (trim($linha) === '') {
                continue;
            }
            $pos = strpos($linha, ':');
            if ($pos === false) {
                continue;
            }
            $frontMatter[trim(substr($linha, 0, $pos))] = trim(substr($linha, $pos + 1));
        }

        $corpo = trim(implode("\n", array_slice($linhas, $sep + 1)));

        return [$frontMatter, $corpo];
    }
}
