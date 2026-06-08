---
epic_id: EPIC-012
type: validation-checklist
created_at: 2026-06-08
---

# Checklist de validação — EPIC-012

> Para o **validador**: execute cada item em ordem. Para cada um, registre status `pass | fail | n/a` e evidência (link, screenshot, log). Não invente resultados. Em caso de falha, **não tente consertar** — registre e devolva para o PO. Verificação visual em **browser real**, nos dois tamanhos (mobile ≥360px e desktop ≥1280px), nos dois temas (claro/escuro).

## 1. Critérios de aceite das estórias

- [ ] Todas as estórias do épico (STORY-076 a STORY-080) estão com `status: done` no `index.json`.
- [ ] Cada critério de aceite (CA) listado em cada `story.md` foi exercido por pelo menos um teste automatizado.

## 2. Navegação (shell)

- [ ] **Contratante**: ao entrar em homologação, vê o menu lateral (rail/drawer) no desktop com todos os destinos do papel; no mobile o mesmo vira navegação inferior.
- [ ] **Profissional**: ao entrar em homologação, vê navegação inferior no mobile; no desktop vira rail lateral.
- [ ] **100% das telas autenticadas** (feed, vagas, candidatos, turnos, detalhe, notificações, perfil) são alcançáveis a partir do shell **sem digitar rota**. Nenhuma tela órfã.
- [ ] Estado **ativo** do item de navegação reflete a tela atual; troca de contexto em 1 toque/clique.
- [ ] O shell **colapsa corretamente** entre os breakpoints do DDR-001 (compact → medium → expanded → large) — sem mobile esticado nem desktop encolhido.
- [ ] RBAC: o shell de cada papel mostra **apenas** os destinos daquele papel (ADR-007); não há vazamento de destino do outro perfil.
- [ ] Cor de chrome (sidebar/rail) segue o perfil (DDR-001): mostarda contratante, verde-sage profissional, nos dois temas.

## 3. Pente fino de UX

- [ ] Toda tela com lista tem **estado vazio** com instrução + próximo passo (não tela em branco).
- [ ] Todo erro recuperável oferece **"tentar de novo"**; erro não-recuperável tem saída clara.
- [ ] Telas com carregamento mostram **skeleton/loading** consistente (não spinner solto sem contexto).
- [ ] Microcopy revisada em pt-BR (DDR-002) — sem texto técnico cru exposto ao usuário não-técnico.

## 4. Acessibilidade (AA)

- [ ] Contraste **WCAG AA** (4.5:1 texto normal / 3:1 texto grande e ícone) em todas as telas tocadas — evidência do gate automatizado (axe/lighthouse) + amostragem manual.
- [ ] Navegação por **teclado** funciona no shell e nas telas (tab order lógico, foco visível).
- [ ] Alvos de toque **≥48dp** nos itens de navegação e ações primárias.
- [ ] Ícone-só como ação tem **label acessível**.

## 5. Cobertura de testes

- [ ] Cobertura unitária do código novo do épico ≥ **80%** (evidência: relatório do CI).
- [ ] Há testes **E2E** (integration_test, Chrome headless — IDR-010/011) cobrindo navegação por papel nos dois tamanhos (mobile e desktop).

## 6. Automação e pipeline

- [ ] Pipeline CI verde no branch principal após o épico.
- [ ] Deploy para homologação automatizado e verificado.

## 7. Documentação e decisões

- [ ] **DDR-003** (padrão de navegação) `accepted` e indexado em `index.json`.
- [ ] `design/system/patterns.md` atualizado com o padrão de navegação composto.
- [ ] SCREEN spec(s) do shell marcadas `shipped`.
- [ ] IDRs criados durante o épico (se houver) indexados.
- [ ] Notas do agente em cada estória preenchidas.

## 8. Veredito

- [ ] **APROVADO** — todos os itens acima `pass` ou `n/a` justificado.
- [ ] **REPROVADO** — pelo menos um `fail`. Liste no relatório quais e devolva ao PO.

Preencha o relatório final em `report.md`.
