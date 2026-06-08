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
status: ready
owner_agent: null
created_at: 2026-06-08
updated_at: 2026-06-08
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
