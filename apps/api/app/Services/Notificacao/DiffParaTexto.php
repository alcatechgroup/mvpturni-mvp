<?php

namespace App\Services\Notificacao;

use App\Models\Funcao;
use App\Support\DataHora;
use Carbon\Carbon;

/**
 * STORY-053 (template 2) — formata o `diff` de uma edição material (STORY-052) numa lista de
 * linhas legíveis "Rótulo: antes → depois", já no padrão pt-BR 24h (DDR-002). Roda na CRIAÇÃO
 * da notificação (não no envio): o payload guarda strings prontas, e o worker de e-mail vira um
 * interpolador puro (sem conhecer tipos de campo).
 */
final class DiffParaTexto
{
    /**
     * @param  list<array{campo:string,label:string,tipo:string,antes:mixed,depois:mixed}>  $diff
     */
    public static function gerar(array $diff): string
    {
        $linhas = [];
        foreach ($diff as $m) {
            $antes = self::valor($m['tipo'], $m['antes']);
            $depois = self::valor($m['tipo'], $m['depois']);
            $linhas[] = "{$m['label']}: {$antes} → {$depois}";
        }

        return implode("\n", $linhas);
    }

    private static function valor(string $tipo, mixed $v): string
    {
        if ($v === null || $v === '') {
            return '—';
        }

        return match ($tipo) {
            'data' => DataHora::completa(Carbon::parse((string) $v)) ?? (string) $v,
            'valor' => 'R$ '.number_format((float) $v, 2, ',', '.'),
            'funcao' => Funcao::find($v)?->nome ?? "Função #{$v}",
            default => (string) $v,
        };
    }
}
