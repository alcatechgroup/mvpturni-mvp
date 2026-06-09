---
story_id: STORY-080
slug: auditoria-acessibilidade-aa-microcopy
title: "Auditoria de acessibilidade AA + navegação por teclado + alvos de toque + microcopy"
epic_id: EPIC-012
sprint_id: SPRINT-2026-W29
type: implementation
target_role: programador
requires_design: true
design_screen_id: null
status: in_progress
owner_agent: claude-opus-programador-2026-06-09
created_at: 2026-06-08
updated_at: 2026-06-09
estimated_session_size: M
produces_idr: null
---

# STORY-080 — Auditoria de acessibilidade AA + microcopy

> **Para o agente que vai executar:** leia esta estória por inteiro. Designer revisa a11y e microcopy junto.

## Contexto (por que esta estória existe)

DDR-001 fixou contraste AA na fundação, mas as telas entregues tela a tela na onda não passaram por uma **auditoria transversal** de acessibilidade e microcopy. Esta estória fecha o pente fino: garante que todas as telas tocadas do WebApp são navegáveis por teclado, têm foco visível, contraste AA, alvos de toque adequados e microcopy clara em pt-BR para público não-técnico.

- Épico: `epics/EPIC-012-shell-navegacao-e-ux/epic.md`
- NFR: `docs/especificacao/non-functional.md` (WCAG AA, texto mínimo, pt-BR). Tokens: contraste (§6 de `tokens.md`).

## O quê (objetivo desta estória)

Auditar e corrigir acessibilidade (contraste AA, foco visível, navegação por teclado, alvos de toque ≥48dp, ícones com label) e microcopy nas telas autenticadas do WebApp; tornar o gate automatizado (axe/lighthouse) verde nessas telas.

## Por quê (valor para o usuário)

Acessibilidade não é "modo à parte" — é a única forma de o produto ser usável por todos os perfis de hospitalidade, inclusive em condições adversas (tela ao sol, pressa, baixa familiaridade com apps). Microcopy clara reduz erro e suporte.

## Critérios de aceite

- [ ] **CA-1:** Contraste **WCAG AA** (4.5:1 texto normal / 3:1 texto grande e ícone) verde em todas as telas autenticadas do WebApp, nos dois temas — evidência do gate automatizado + amostragem manual.
- [ ] **CA-2:** Navegação por **teclado** funciona em todas as telas tocadas (tab order lógico, foco sempre visível, sem armadilha de foco).
- [ ] **CA-3:** Alvos de toque **≥48dp** em ações primárias e itens de navegação; ícone-só como ação tem **label acessível**.
- [ ] **CA-4:** Mensagens de erro associadas ao campo (não só cor); microcopy revisada em pt-BR (DDR-002) sem termos técnicos crus.
- [ ] **CA-5:** O **gate automatizado de acessibilidade** (axe/lighthouse — `quality-standards.md`) roda no CI para as telas do WebApp e está verde; regressão futura passa a ser pega pelo gate.
- [ ] **CA-6:** Correções não introduzem regressão funcional (suítes existentes verdes); mudanças de microcopy de domínio que exijam decisão de produto são escaladas ao PO, não decididas no código.
- [ ] **CA-7:** Deploy homologação verificado.

## Fora de escopo

- Shell e telas novas. Redesign visual. Backoffice.
- Conformidade AAA (alvo é AA).

## Padrões de qualidade exigidos

`docs/skills/po/references/quality-standards.md` — inclui o gate de acessibilidade automatizado para FE web. ≥80% no código alterado.

## Dependências

- **Bloqueada por:** STORY-078 (telas já no shell; auditar o estado final) e idealmente STORY-079 (estados novos já existindo para auditar).
- **Bloqueia:** STORY-081 (validação).

## Decisões já tomadas (não as reabra)

- DDR-001 (contraste AA, tokens), DDR-002 (pt-BR/24h), `non-functional.md` (WCAG AA).

## Liberdade técnica do agente

Decide: como instrumentar o gate axe/lighthouse no CI, correções de a11y, estrutura dos testes.

NÃO decide: copy de domínio que mude significado (PO), alvo de conformidade (AA, fixado), CAs.

## Definição de Pronto (DoD)

- [ ] CAs passam; gate de a11y verde no CI; suítes existentes verdes.
- [ ] Pipeline verde; deploy homolog verificado.
- [ ] IDR registrado se a instrumentação do gate gerar padrão reutilizável.
- [ ] `index.json` atualizado: status = `done`. "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

`docs/skills/po/references/agent-task-format.md`. Designer revisa a11y e microcopy no PR.

## Notas do agente (preenchido durante/após execução)

### Plano inicial (registrado antes de codar — 2026-06-09)

**Documentos lidos:** estória inteira; `agent-task-format.md`; `quality-standards.md` (§1, §2.2, §5); `programador/SKILL.md`; `designer/references/accessibility-basics.md` (os 7 pontos do piso); `tokens.md §6` (tabela de contraste sancionada WCAG AA); DDR-001/002; `.github/workflows/ci.yml`; `Makefile` (alvos de teste); `scripts/hooks/pre-push`; `router.dart` (superfície autenticada); `theme.dart`/`tokens.dart`; agent_notes da STORY-079.

**Entendimento consolidado:** o pente-fino de a11y fecha o que a fundação (DDR-001) fixou em tokens mas que nunca foi auditado transversalmente nas telas entregues onda a onda. Os tokens de contraste já são AA-sancionados (`tokens.md §6`); o risco está em telas que usam cores fora da lista, `IconButton`/gesto sem label, alvos <48dp, e erro só-cor. Superfície autenticada (dentro do `StatefulShellRoute`): MinhasVagas, Feed, VagaDetalhe, EditarVaga, PublicarVaga, PainelCandidatos, TurnosLista, TurnoDetalhe, CronometroPoc, Perfil, AppShellScreen, PIN check-in/checkout, e o próprio AppShell (rail/nav). Fora: login/recuperação/welcome/pré-cadastro (públicas) e Backoffice.

**Decisão técnica central (vira IDR):** o gate automatizado de a11y será feito com os **matchers nativos do Flutter `meetsGuideline`** (`textContrastGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline`), rodando em `flutter test` (sem browser, sem banco) — **não** axe/lighthouse. Motivo: o WebApp é Flutter **canvas-rendered** (CanvasKit) — axe/lighthouse enxergam um `<canvas>` quase vazio e dariam falso-verde. Os matchers operam sobre a árvore de Semântica que o Flutter exporta, que é exatamente o que vira ARIA no DOM, e cobrem CA-1 (contraste AA), CA-3 (alvo ≥48dp + label). A `(axe/lighthouse)` da CA-5 é parentético; `quality-standards.md §5/§6` deixa a ferramenta a cargo do time e exige só o resultado (gate verde, regressão pega). Vou adicionar `flutter test` ao CI (job Flutter) para a CA-5 "roda no CI" valer literalmente — é barato (sem browser/DB).

**Mapeamento CA → testes (a escrever, TDD — vermelho antes):**
- CA-1 (contraste AA, 2 temas): `meetsGuideline(textContrastGuideline)` por tela autenticada, claro + escuro.
- CA-2 (teclado): coberto pela suíte E2E em browser real (`integration_test`) — cenário de tab-order/foco; matcher não cobre teclado.
- CA-3 (alvo ≥48dp + ícone-só com label): `meetsGuideline(androidTapTargetGuideline)` + `meetsGuideline(labeledTapTargetGuideline)` por tela.
- CA-4 (erro associado ao campo + microcopy pt-BR): testes de `errorText` no validator dos forms; microcopy de domínio → escalar ao PO, não decidir no código.
- CA-5 (gate no CI verde): step `flutter test` no `ci.yml` + IDR.
- CA-6 (sem regressão): suíte completa verde.
- CA-7 (deploy homolog): tag rc + smoke.

**Plano (5 passos):**
1. Construir helper de a11y (`test/a11y/a11y_harness.dart`) que pumpa um widget nos 2 temas e roda os 3 guidelines; probe de descoberta para listar violações reais (a auditoria).
2. Por tela: teste a11y vermelho → corrigir a11y (tooltip/Semantics/tap-target/cor sancionada) → verde. Commits pequenos.
3. CA-4: auditar forms (errorText) + microcopy; flag de copy de domínio ao PO.
4. CA-2: cenário de teclado no `integration_test`.
5. Wire CI (`flutter test`) + IDR + suíte completa verde + deploy homolog.

**Dúvidas/flags:** copy de domínio que mude significado → PO (ex.: resíduo "Member Start:" no vazio de candidatos já flagrado na STORY-079). Não reabro DDR-001/002.

### Decisões tomadas
- 

### Descobertas
- 

### Bloqueios encontrados
- 

### Cobertura final
- Unitários:  / Gate a11y: 

### Links de evidência
- PR / Pipeline / Deploy homolog: 
