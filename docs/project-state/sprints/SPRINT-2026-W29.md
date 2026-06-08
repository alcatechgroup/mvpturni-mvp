---
sprint_id: SPRINT-2026-W29
wave: WAVE-2026-01
status: planned  # planned | active | closed
start_date: 2026-06-08
end_date: null  # fechamento por goal-atingido
opened_at: 2026-06-08
opened_by: "PO (Alexandro / Claude)"
soft_cap_date: 2026-07-06  # ~28 dias corridos — folga padrão; sprint de UX é majoritariamente front-end
closure_rule: "Fechamento por goal-atingido: encerra quando STORY-076..080 estiverem `done` E STORY-081 (validador) emitir veredito em `validation/report.md` aceitável pelo PO (`approved` ou `approved_with_pending` que o PO assuma como goal-atingido). STORY-082 (deflake cronômetro + housekeeping) é ortogonal — carry-forward do veredito da W28 (F-B-1 + F-NB-4); pode iniciar imediatamente e não bloqueia o goal. Soft-cap 2026-07-06 serve como gatilho de reavaliação, não prazo de entrega."
goal: "WebApp com shell de navegação coerente e responsivo (EPIC-012): Contratante navega por menu lateral (rail/drawer) no desktop e Profissional por navegação inferior no mobile, ambos responsivos nos dois tamanhos; 100% das telas autenticadas alcançáveis pelo shell sem digitar rota (nenhuma órfã); estados vazios/erro/carregamento padronizados; acessibilidade AA verde nas telas tocadas. Padrão de navegação registrado em DDR-003. Em paralelo (ortogonal): STORY-082 quita as dívidas do veredito da W28 — deflake do E2E de sincronia do cronômetro (F-B-1, gate de release) + housekeeping do índice (F-NB-4)."
---

# SPRINT-2026-W29

## Objetivo do sprint

A SPRINT-2026-W28 fechou o EPIC-003 em 2026-06-07 — o ciclo do turno está vivo ponta a ponta em homologação e os três pilares da promessa pública estão demonstrados. No fechamento, o PO registrou o compromisso de uma **pausa explícita entre EPIC-003 e EPIC-004**. Por **PDR-018**, essa pausa é preenchida com uma sprint de **UX/UI**: abrir o **EPIC-012 — Shell de navegação e pente fino de UX do WebApp**, melhorando a usabilidade de tudo que já foi entregue **antes** de adicionar a próxima feature (EPIC-004, avaliação recíproca).

O problema que esta sprint resolve: o WebApp foi construído tela a tela, sem shell de navegação global (a própria STORY-059 documenta ter evitado introduzir `NavigationBar` por ser decisão de DDR; `patterns.md` confirma que nenhum padrão de navegação foi catalogado). O **Contratante** opera no desktop sem menu lateral; o **Profissional** opera no mobile sem navegação inferior persistente. Esta sprint entrega o shell responsivo para os dois papéis e faz o pente fino de UX (estados vazios/erro/carregamento, acessibilidade AA, microcopy).

A natureza do trabalho (UX/UI, majoritariamente front-end) é **deliberadamente diferente** do coração transacional da W28 — o que honra o espírito da pausa (descompressão cognitiva) sem deixar a janela ociosa.

## Escopo e duração

- **Escopo**: **7 estórias** — EPIC-012 inteiro (1 spike de Designer + 4 implementação + 1 validação) + STORY-082 (carry-forward das dívidas do veredito W28, ortogonal). Mix: **1 S + 5 M + 1 L**.
  - A **L** (STORY-077, app shell) é candidata natural a quebra de sessão. Gatilho documentado na própria estória: separar (a) shell + roteamento + navegação por papel de (b) integração das telas iniciais. Agente escala ao PO **antes** de inflar (padrão W28).
- **Superfícies**: WebApp **Contratante (desktop)** + **Profissional (mobile)**, ambas responsivas. **Backoffice admin fora** (já desktop-first com sidebar própria — PDR-018).
- **Duração**: aberta, com **fechamento por goal-atingido** (padrão consolidado W22→W28). Soft-cap em **2026-07-06** (~28 dias) como gatilho de reavaliação, não prazo.

## Estórias incluídas

| ID        | Título                                                                                | Épico    | Tipo           | Papel                    | Tamanho | Status |
| --------- | ------------------------------------------------------------------------------------- | -------- | -------------- | ------------------------ | ------- | ------ |
| STORY-076 | Spike Designer — padrão de navegação global (DDR-003) + protótipo                     | EPIC-012 | spike          | designer                 | M       | ready  |
| STORY-077 | App shell adaptativo (rail/drawer desktop ↔ nav inferior mobile) + destinos por papel | EPIC-012 | implementation | programador (+ designer) | L       | ready  |
| STORY-078 | Migrar telas existentes para o shell (nenhuma órfã) + contexto/título no desktop      | EPIC-012 | implementation | programador (+ designer) | M       | ready  |
| STORY-079 | Padronizar estados vazios, erro e carregamento (skeleton)                             | EPIC-012 | implementation | programador (+ designer) | M       | ready  |
| STORY-080 | Auditoria de acessibilidade AA + teclado + alvos de toque + microcopy                 | EPIC-012 | implementation | programador (+ designer) | M       | ready  |
| STORY-081 | Validação final do EPIC-012                                                           | EPIC-012 | validation     | validador                | M       | ready  |
| STORY-082 | Deflake cronômetro (F-B-1) + housekeeping índice (F-NB-4) — carry-forward W28         | EPIC-003 | bugfix         | programador              | S       | ready  |

**Sizing total**: **1 S + 5 M + 1 L (7 estórias)**.

## Ordem de execução obrigatória

```
STORY-076 (spike Designer — DDR-003 + protótipo aprovado pelo humano)
    │ DDR-003 accepted + protótipo "vai"
    ▼
STORY-077 (app shell adaptativo + roteamento + destinos por papel)
    │ shell vivo em homolog
    ├─► STORY-078 (migrar telas para o shell — nenhuma órfã)
    │       │
    │       └─► STORY-080 (auditoria a11y AA + microcopy — audita o estado final)
    └─► STORY-079 (estados vazios/erro/loading — em paralelo com 078, coordenando telas)
                                                    │ 077..080 done
                                                    ▼
                                             STORY-081 (validador — última)

STORY-082 (deflake cronômetro + housekeeping) — ORTOGONAL TOTAL, sem dependência, inicia a qualquer momento
```

**Por que esta ordem.** O DDR-003 (decisão de design durável) precede toda implementação — o shell não pode ser codificado antes de o padrão estar decidido e o protótipo aprovado pelo humano (disciplina "spike/decisão antes de implementação", lição W27/W28). A migração (078) depende do shell existir (077). A auditoria de a11y (080) audita o **estado final** das telas, então vem depois de 078 e idealmente de 079. Estados (079) podem rodar em paralelo com a migração desde que coordenem as telas tocadas. STORY-082 não toca nada do EPIC-012 — inicia imediatamente.

## Compromisso visível ao fim do sprint

**Em `app.homolog.turni.com.br` (WebApp Flutter):**

- **Contratante** entra e vê um **menu lateral** (rail/drawer) no desktop com todos os destinos do seu papel; troca de contexto em 1 clique; no mobile o mesmo colapsa para navegação inferior. Chrome em mostarda (DDR-001), nos dois temas.
- **Profissional** entra e vê **navegação inferior** persistente no mobile com seus destinos; no desktop vira rail lateral. Chrome em verde-sage.
- **Todas as telas já entregues** (feed, minhas vagas, candidatos, turnos, detalhe, notificações, perfil) estão plugadas no shell — nenhuma órfã; deep-links abrem dentro do shell com o destino certo ativo.
- **Estados vazios/erro/carregamento** padronizados (instrução + próximo passo; erro com "tentar de novo"; skeleton no carregamento).
- **Acessibilidade AA** verde no gate automatizado nas telas tocadas (contraste, teclado, foco, alvos ≥48dp, ícones com label).

**Decisões registradas:**

- **DDR-003** — padrão de navegação global do WebApp (widget por breakpoint, destinos por papel, responsividade, estado ativo, chrome por perfil). Reflexo em `design/system/patterns.md`.
- IDR(s) eventuais de roteamento aninhado / instrumentação do gate de a11y, se a implementação tomar decisão local relevante.

**Dívida da W28 quitada (ortogonal):** E2E de sincronia do cronômetro estável (gate de release confiável) + `index.json` reconciliado (IDR-028 indexado; STORY-056-B coerente).

## Decisões de produto/arquitetura que entram em vigor agora

- **PDR-018** (novo) — sprint de UX/UI antes do EPIC-004; navegação como DDR; superfícies WebApp contratante+profissional; Backoffice fora.
- **DDR-003** (a ser produzido na STORY-076) — padrão de navegação.
- **ADRs/DDRs/PDRs vigentes respeitados**: ADR-001 (Flutter), ADR-007 (RBAC por papel), ADR-018 (UUID em rotas), DDR-001 (fundação DS, breakpoints, chrome por perfil), DDR-002 (pt-BR/24h), PDR-003 (duas interfaces; contratante desktop-first), PDR-013 (dual-theme), IDR-010/011 (modelo E2E), IDR-020/025 (PWA + restauração de sessão — não regredir).
- **Pendência de papel que não bloqueia** (herdada da W28): revisão de ADR-005/ADR-016 pós-PDR-017 pelo Arquiteto — segue aberta, não afeta esta sprint.

## Riscos identificados na abertura

| Risco | Probabilidade | Impacto | Mitigação | Owner |
|---|---|---|---|---|
| Designer vira gargalo — DDR-003 + protótipo (STORY-076) atrasa e bloqueia toda a implementação | alta | alto | STORY-076 é a primeira e única dependência dura; PO prioriza a aprovação do protótipo no D1-D2; enquanto o DDR não fecha, 077/078 ficam `blocked` (não se começa shell sem padrão) — STORY-082 (ortogonal) preenche a janela | Designer + PO |
| STORY-077 (shell, L) estoura sessão única — roteamento aninhado + adaptatividade é tecnicamente novo no WebApp | média | médio | Gatilho de quebra documentado (shell+roteamento vs integração de telas); DDR-003 entrega a decisão de padrão antes de a estória começar | Programador + PO |
| Migração das telas (078) quebra deep-links existentes (bookmarks, links de notificação/e-mail da STORY-067) | média | alto | CA-4 da STORY-078 exige deep-links preservados abrindo dentro do shell; E2E cobre 1 deep-link por papel; PO verifica em homolog | Programador + Validador |
| Regressão de RBAC ao reorganizar roteamento — destino de um papel vaza para o outro | baixa | alto | CA de RBAC fail-secure em 077 e 078; E2E cruzado herdado da W28 não pode regredir | Programador + Validador |
| Gate de a11y (axe/lighthouse) ainda não instrumentado no CI — STORY-080 precisa criá-lo, pode estourar o S/M | média | médio | STORY-080 é M justamente por incluir a instrumentação; se o gate exigir trabalho de infra além do esperado, escalar ao PO para separar instrumentação de correções | Programador + PO |
| Pente fino expõe necessidade de copy de domínio que é decisão de produto (não de design) | média | baixo | Estórias 079/080 mandam escalar ao PO mudanças de microcopy que alterem significado; PO disponível para sessão curta de copy | PO |
| "Pausa entre épicos" vira sprint cheia — risco de não descomprimir de fato | média | baixo | Trabalho de UX é de natureza diferente do transacional da W28; fechamento por goal-atingido sem pressão de prazo; soft-cap com folga | Alexandro |
| STORY-082 (deflake) não estabiliza — o flake é estrutural (timing em build debug) | média | médio | A estória permite **re-especificar** a medição (não só repetir o teste); IDR registra a nova forma; se não estabilizar, PO decide tratar como dívida explícita renovada em vez de bloquear a sprint | Programador + PO |

## Acompanhamento contínuo (PO)

- **Diário (~10 min)**: olhar `index.json`; desbloquear sobretudo a aprovação do protótipo da STORY-076 (gargalo de entrada) e microcopy escalada.
- **Mid-sprint check**: verificar se DDR-003 fechou e 077 destravou; se STORY-077 foi quebrada, avaliar sessão extra.
- **Soft-cap check em 2026-07-06**: se goal não bateu, abrir "Mudanças no escopo" e decidir.

### Registro de acompanhamento

| Data | Check | Situação |
|---|---|---|
| 2026-06-08 | Abertura da sprint (PO) | Sprint criada por PDR-018 ocupando a pausa entre EPIC-003 e EPIC-004. EPIC-012 `ready` com 6 estórias + STORY-082 carry-forward. Próximo passo: agente Designer executa STORY-076 (DDR-003 + protótipo) e apresenta ao humano. |

## Mudanças no escopo do sprint

> Toda alteração no conjunto de estórias após esta abertura registra aqui, com data e motivo.

| Data | O que mudou | Motivo | Custo |
|---|---|---|---|
| — | — | — | — |

## Fechamento do sprint (preencher no encerramento)

### O que foi entregue
- 

### O que ficou para trás (e por quê)
- 

### Aprendizados de produto
- 

### Aprendizados de processo
- 

### Ajustes para o próximo sprint
- 
