<?php

// STORY-058 (CA-2, CA-4) — motor de renderização do aceite POR TURNO. Diferente do aceite de
// adesão (AceiteAdesaoRenderer, que descarta a Seção 2), o aceite do turno renderiza o documento
// INTEIRO (Seção 1 + Seção 2 + Assinatura) e resolve a cláusula condicional de override de
// habitualidade (PDR-002 / compliance.md): bloco `###` marcado com {{habitualidade.override_aceito}}
// entra somente quando o contratante assumiu o risco (3ª alocação PJ).

use App\Domain\Contratos\AceiteTurnoRenderer;
use App\Domain\Contratos\RenderizacaoIncompletaException;

const TPL_TURNO = <<<'MD'
# Contrato de teste

## Seção 1 — Termos gerais aplicáveis a todo turno

Nome: **{{profissional.nome}}**

## Seção 2 — Termos do turno específico

Razão Social: **{{contratante.razao_social}}**
Valor: {{turno.valor}}

### 10. Aceite consciente de risco de habitualidade

*Este bloco é exibido somente quando `{{habitualidade.override_aceito}} = true` — alerta PDR-002.*

---

O **Contratante** declara, expressamente e de forma consciente, que assume o risco.

---

## Assinatura eletrônica

Aceito em {{aceite.timestamp}}.

## Histórico de validação

| Data | Validador |
|---|---|
| 2026-05-28 | PO |

## Notas do PO

Metadados de autoria que nunca entram no aceite.
MD;

function contextoTurno(): array
{
    return [
        'profissional.nome' => 'Júlia Santos',
        'contratante.razao_social' => 'Bar do Zé Ltda',
        'turno.valor' => 'R$ 200,00',
        'aceite.timestamp' => '12/06/2026 14:20',
    ];
}

// ─── (a) caminho feliz ────────────────────────────────────────────────────────

it('renderiza Seção 1 + Seção 2 + Assinatura com placeholders substituídos', function () {
    $render = (new AceiteTurnoRenderer)->renderizar(TPL_TURNO, contextoTurno(), false);

    expect($render)
        ->toContain('Júlia Santos')
        ->toContain('Bar do Zé Ltda')
        ->toContain('R$ 200,00')
        ->toContain('Aceito em 12/06/2026 14:20')
        ->toContain('## Seção 2 — Termos do turno específico');
});

it('descarta os blocos de metadados (Histórico de validação, Notas do PO)', function () {
    $render = (new AceiteTurnoRenderer)->renderizar(TPL_TURNO, contextoTurno(), false);

    expect($render)
        ->not->toContain('Histórico de validação')
        ->not->toContain('Notas do PO');
});

// ─── (b) cláusula condicional de override (PDR-002) ──────────────────────────

it('sem override: remove a cláusula de aceite de risco inteira', function () {
    $render = (new AceiteTurnoRenderer)->renderizar(TPL_TURNO, contextoTurno(), false);

    expect($render)
        ->not->toContain('Aceite consciente de risco de habitualidade')
        ->not->toContain('assume o risco')
        ->not->toContain('{{habitualidade.override_aceito}}');
});

it('com override: mantém a cláusula e remove a linha-diretiva do template', function () {
    $render = (new AceiteTurnoRenderer)->renderizar(TPL_TURNO, contextoTurno(), true);

    expect($render)
        ->toContain('### 10. Aceite consciente de risco de habitualidade')
        ->toContain('declara, expressamente e de forma consciente')
        // A diretiva é instrução ao motor, não conteúdo contratual — nunca aparece.
        ->not->toContain('Este bloco é exibido somente quando')
        ->not->toContain('{{habitualidade.override_aceito}}');
});

it('template sem cláusula de override (PF) renderiza normal mesmo com override=true', function () {
    $semClausula = preg_replace('/### 10\..*?(?=## Assinatura)/s', '', TPL_TURNO);

    $render = (new AceiteTurnoRenderer)->renderizar($semClausula, contextoTurno(), true);

    expect($render)->toContain('Júlia Santos')->not->toContain('Aceite consciente');
});

// ─── (c) exceções esperadas ───────────────────────────────────────────────────

it('placeholder sem valor no contexto falha duro (nenhum aceite incompleto)', function () {
    $contexto = contextoTurno();
    unset($contexto['turno.valor']);

    expect(fn () => (new AceiteTurnoRenderer)->renderizar(TPL_TURNO, $contexto, false))
        ->toThrow(RenderizacaoIncompletaException::class);
});

// ─── (d) bordas ───────────────────────────────────────────────────────────────

it('conteúdo sem nenhum bloco omitido nem cláusula passa intacto (só substituição)', function () {
    $minimo = "# Doc\n\nOlá {{profissional.nome}}.\n";

    $render = (new AceiteTurnoRenderer)->renderizar($minimo, ['profissional.nome' => 'Ana'], false);

    expect($render)->toBe("# Doc\n\nOlá Ana.\n");
});

it('contexto com chaves extras não usadas não falha', function () {
    $render = (new AceiteTurnoRenderer)->renderizar(
        "Olá {{a}}.\n",
        ['a' => 'X', 'habitualidade.override_aceito' => 'false'],
        false,
    );

    expect($render)->toBe("Olá X.\n");
});
