<?php

// STORY-045 / ADR-014 (CA-4) — o NÚCLEO do match é função pura: sem leitura de banco,
// sem clock, sem container. Teste de arquitetura: varre os arquivos do núcleo e
// rejeita tokens proibidos. O adapter MatchScoring (cola para Eloquent) é a fronteira
// e fica fora desta varredura de propósito.

$nucleo = [
    'EstadoComponente.php',
    'BreakdownItem.php',
    'MatchInput.php',
    'MatchScore.php',
    'MatchCalculator.php',
];

$proibidos = [
    'now(',            // clock
    'Carbon',          // clock
    'DB::',            // banco
    '::query(',        // banco
    '->save(',         // banco
    '->get(',          // banco
    'app(',            // service locator
    'resolve(',        // service locator
    'request(',        // request global
    'App\\Models',     // Eloquent no núcleo
];

test('o núcleo do match não lê banco nem clock (CA-4)', function () use ($nucleo, $proibidos) {
    $base = app_path('Domain/Match');

    foreach ($nucleo as $arquivo) {
        $conteudo = file_get_contents("{$base}/{$arquivo}");
        expect($conteudo)->not->toBeFalse();

        foreach ($proibidos as $token) {
            expect(str_contains($conteudo, $token))
                ->toBeFalse("núcleo do match '{$arquivo}' contém token proibido '{$token}' (CA-4: função pura)");
        }
    }
});
