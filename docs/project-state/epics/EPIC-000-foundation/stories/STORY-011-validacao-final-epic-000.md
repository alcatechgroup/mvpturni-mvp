---
story_id: STORY-011
slug: validacao-final-epic-000
title: Validação final do EPIC-000 Foundation
epic_id: EPIC-000
sprint_id: SPRINT-2026-W23
type: validation
target_role: validador
requires_design: false
status: in_progress
owner_agent: claude-sonnet-4-6-validador
created_at: 2026-05-26
updated_at: 2026-05-28
estimated_session_size: M
---

# STORY-011 — Validação final do EPIC-000 Foundation

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar. **Como Validador, você não conserta nada** — observa, registra evidência, e produz veredito `approved` ou `rejected`. Se algum item falhar, devolve para o PO via `validation/report.md` propondo estórias de correção; não corrige diretamente.

## Contexto (por que esta estória existe)

O EPIC-000 só pode ser marcado como `done` quando um **validador independente** executa a bateria de validação e produz veredito (`docs/skills/po/SKILL.md` Fluxo D + `docs/skills/po/references/agile-workflow.md` "Quando um épico termina"). Esta é a última estória do épico — `target_role: validador` — e marca o ponto em que a métrica primária do épico ("merge em main dispara deploy automático para ambas as homologações em ≤ 10 min, repetível 3x, com health-check verde") é **observada por terceiros**, não declarada pelo autor.

A validação cobre: critérios de aceite das 10 estórias anteriores, cobertura de testes, automação, IaC, funcionalidade observável, qualidade transversal (segurança, LGPD, migrações reversíveis), documentação. Detalhe operacional do checklist está em `docs/project-state/epics/EPIC-000-foundation/validation/checklist.md` (a ser criado pelo PO antes desta estória entrar em sprint, ou pelo próprio Validador a partir do template em `docs/skills/po/templates/validation-checklist.md` se ainda não existir).

- Épico: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Documentos canônicos a ler ANTES de validar:
  - `docs/skills/validador/SKILL.md`
  - `docs/skills/po/templates/validation-checklist.md` (base do checklist)
  - `docs/project-state/epics/EPIC-000-foundation/epic.md` (entregável visível, métrica de sucesso, definição de épico concluído)
  - `docs/skills/po/references/quality-standards.md` (régua de qualidade transversal)
  - Todas as 10 estórias anteriores do EPIC-000 (STORY-001 a STORY-010) com seus CAs
  - Todas as 9 ADRs propostas e aceitas (ADR-000 a ADR-008) e DDR-001
  - PDRs aplicáveis (PDR-002, PDR-003, PDR-004 — citados nas estórias)
  - `docs/project-state/index.json` (estado declarado)
  - `docs/especificacao/non-functional.md` (SLOs e NFRs aplicáveis)

## O quê (objetivo desta estória)

Executar a validação independente do EPIC-000 e produzir:

1. **`docs/project-state/epics/EPIC-000-foundation/validation/checklist.md`** preenchido — cada item com status `pass | fail | n/a` e evidência (link, screenshot, log, comando).
2. **`docs/project-state/epics/EPIC-000-foundation/validation/report.md`** — relatório final com veredito `approved` ou `rejected`, resumo executivo, evidências consolidadas, e (se reprovado) propostas de estórias de correção para o PO.
3. **Atualização do `index.json`**: `epics[].validation_report` apontando para o `report.md`. Se aprovado, o PO (em sessão separada) marca `epic.status = done`; se reprovado, `epic.status` permanece `in_review` e o PO abre estórias de correção.

## Por quê (valor para o usuário)

O validador independente é o **portão de qualidade** que protege os usuários (profissional e contratante futuros) de receber código que parece pronto mas não está. Para o **time**, é o sinal de que o EPIC-000 cumpriu o que prometeu — fundação confiável que sustenta o resto da onda. Para o **Alexandro como PO**, é a evidência objetiva que ele precisa para abrir a próxima sprint do EPIC-001 sem dúvida sobre se a fundação aguenta.

A métrica primária do EPIC-000 (3 deploys consecutivos ≤ 10 min com health-check verde) é, propositadamente, observável **por terceiros** — esta estória é onde ela é confirmada.

## Critérios de aceite

### Checklist completo

- [ ] **CA-1:** `validation/checklist.md` existe e cobre, no mínimo, todas as seções de `docs/skills/po/templates/validation-checklist.md` adaptadas ao EPIC-000 (critérios de aceite das estórias, cobertura de testes, automação, funcionalidade observável, qualidade transversal, documentação, veredito).
- [ ] **CA-2:** Cada item do checklist tem **status registrado** (`pass | fail | n/a`) e **evidência** (link para CI, screenshot, log, ou comando reprodutível). Item sem evidência é tratado como `fail`.
- [ ] **CA-3:** Validador **não** justifica `fail` em "vai funcionar depois" — `fail` é `fail`; aprovação tardia exige nova execução da validação após o PO abrir estórias de correção.

### Métrica primária do EPIC-000

- [ ] **CA-4:** Validador observa pessoalmente (ou via evidência irrefutável de CI) **3 merges consecutivos em `main`** que dispararam deploy automático ≤ 10 min para ambas as URLs com health-check verde no fim. Tempos exatos registrados no relatório. Se a evidência mostrar < 3 merges válidos consecutivos, ou se algum extrapolou 10 min, ou se health-check ficou amarelo/vermelho em algum deles, é `fail` na métrica primária — bloqueia aprovação.

### Funcionalidade observável

- [ ] **CA-5:** Validador acessa `https://app.homolog.turni.com.br` e verifica: página inicial renderiza, versão exibida coerente com tag deployada, link para `/health` funciona, `/health` retorna 200 com payload conforme ADR-008. Captura screenshots ou registra trace.
- [ ] **CA-6:** Validador acessa `https://admin.homolog.turni.com.br` e verifica o equivalente (identificada como Backoffice, versão visível, `/health` 200).
- [ ] **CA-7:** Validador percorre **manualmente em homologação** o caminho feliz mínimo (abrir ambas as URLs, ver health-check) e atesta que funciona — `quality-standards.md` checklist seção 4 ("um usuário consegue percorrer o fluxo end-to-end manualmente").

### Cobertura, testes e automação

- [ ] **CA-8:** Cobertura unitária do código novo do épico ≥ 80% (relatório do CI ou ferramenta de cobertura — link).
- [ ] **CA-9:** Cobertura em módulos de núcleo/regras de negócio ≥ 98% — N/A aplicável no EPIC-000 (não há regras de negócio implementadas além das mínimas de `/health` e exibição de versão); validador anota `n/a` justificando.
- [ ] **CA-10:** Testes E2E em browser real existem para ambas as interfaces (saídas de STORY-008 e STORY-009) e rodam verdes na pipeline de homologação.
- [ ] **CA-11:** Setup local em 1 comando funciona em máquina limpa (testado em runner limpo conforme CA-8 de STORY-006 e CA-14 de STORY-007 — evidência: log do job agendado).
- [ ] **CA-12:** IaC versionado em git; recriar homologação a partir do código é runbook documentado (`quality-standards.md` seção 2.3).
- [ ] **CA-13:** Rollback documentado e ao menos uma vez testado em homologação (saída de STORY-007 CA-10).

### Decisões registradas

- [ ] **CA-14:** As **9 ADRs** previstas em `epic.md` (ADR-000 a ADR-008) existem em `docs/project-state/decisions/adr/` com `status: accepted` e `approved_by` preenchido. `index.json` reflete o estado.
- [ ] **CA-15:** **DDR-001** existe em `docs/project-state/decisions/ddr/` com `status: accepted` e `approved_by` preenchido. `index.json` reflete.
- [ ] **CA-16:** Para cada IDR criado durante o épico (saída esperada das estórias 006, 007, 008, 009 conforme decisões transversais surgiram), há entrada em `decisions.idr[]` do `index.json` e arquivo em `docs/project-state/decisions/idr/`.
- [ ] **CA-17:** **Todas as 11 estórias** do EPIC-000 estão com `status: done` em `index.json` (esta inclusa após aprovação; se reprovação parcial, estórias com problema voltam a `in_review` e o PO age).

### Qualidade transversal

- [ ] **CA-18:** Scanner de segurança no CI passou em todas as estórias do épico — nenhum aviso crítico aberto introduzido pelo épico (`quality-standards.md` seção 4).
- [ ] **CA-19:** Nenhum segredo commitado em git (verificação por gitleaks ou equivalente — saída de STORY-007).
- [ ] **CA-20:** Migrações de banco testadas como **reversíveis** em homologação (mesmo que apenas a inicial vazia exista, o aparato é exercido).
- [ ] **CA-21:** LGPD: nenhum dado pessoal sendo coletado ainda — `n/a` para esta validação (entra a partir do EPIC-001).
- [ ] **CA-22:** Health-check externo (saída de STORY-007 CA-11) está ativo e alerta plugado a canal real do Alexandro.

### Documentação

- [ ] **CA-23:** READMEs do repositório, WebApp e Backoffice atualizados e coerentes com o estado final do épico.
- [ ] **CA-24:** "Notas do agente" preenchidas em todas as 10 estórias anteriores (saída esperada de cada protocolo do agente).

### Relatório final

- [ ] **CA-25:** `validation/report.md` produzido com: data, validador, escopo (referência ao `epic.md`), resumo executivo (1 parágrafo), tabela de itens do checklist com status e evidência, lista de IDRs/ADRs/DDRs criadas, **veredito final** (`approved` se 100% dos itens são `pass` ou `n/a` justificado; `rejected` se 1+ é `fail`), e — se reprovado — propostas concretas de estórias de correção para o PO (`STORY-012`, `STORY-013`, etc).
- [ ] **CA-26:** `index.json` atualizado: `epics[id == EPIC-000].validation_report` aponta para `epics/EPIC-000-foundation/validation/report.md`; `decisions.idr[]` enumerados; esta estória em `status: done` apenas após o relatório estar mergeado.

## Fora de escopo

- **Consertar** qualquer item reprovado — Validador não consertar; abre proposta de estória de correção no relatório e devolve para o PO (`docs/skills/po/SKILL.md` Fluxo D).
- Reabrir decisões de produto (PDR), arquitetura (ADR) ou design (DDR) — Validador observa que estão registradas; não opina sobre conteúdo.
- Mudar `epic.status` para `done` — isso é ação do PO em sessão separada após ler o relatório e atualizar o estado em decorrência (`agile-workflow.md`).
- Validar épicos futuros (EPIC-001 em diante) — outras estórias de validação no fim de cada um.

## Padrões de qualidade exigidos

Estória **validation** — segue `docs/skills/po/references/quality-standards.md` com exceções específicas declaradas:

- **Cobertura unitária / E2E:** N/A — Validador não escreve código de produção. Roda os testes existentes e atesta resultado, não escreve novos.
- **Rigor aplicável:** evidência obrigatória para cada item; sem `pass` baseado em "confio que está OK"; checklist exaustivo; relatório claro o suficiente para o PO agir sem ambiguidade.
- **Independência:** Validador não é o autor das estórias que está validando — em time pequeno (Alexandro nos 5 papéis), o ato de "trocar de papel" para Validador exige sessão dedicada e disciplina de não defender o trabalho feito em outro papel.

## Dependências

- **Bloqueada por:** todas as 10 estórias anteriores em `status: done` (STORY-001 a STORY-010). Esta estória **não pode** começar enquanto qualquer uma estiver fora de `done`.
- **Bloqueia:** marcar EPIC-000 como `done` (ação do PO após ler relatório aprovado).
- **Pré-requisitos de ambiente:** acesso de leitura ao repositório, ao CI, às URLs de homologação, ao destino de logs (definido em ADR-008), ao canal de alerta.

## Decisões já tomadas (não as reabra)

- **`docs/skills/po/SKILL.md` Fluxo D** — fluxo de fim de épico; Validador segue o protocolo.
- **`epic.md` do EPIC-000** — define o entregável visível, a métrica primária, e a definição de "épico concluído". Validador valida contra isso, não contra escopo inventado.
- **`quality-standards.md`** — régua transversal; Validador atesta cumprimento.
- **Nunca marque épico como concluído sem relatório do validador** (`docs/skills/po/SKILL.md`).

## Liberdade técnica do agente

Você (agente validador) decide:
- Sequência de execução do checklist (sugerimos seguir a ordem do template, mas livre).
- Como capturar evidência (screenshot, copy de log, gravação asciinema, link de CI — o que for verificável).
- Critérios para classificar item ambíguo como `pass` vs `fail` (tenda para o conservador — em dúvida, `fail` com nota explicativa).
- Forma do relatório final (dentro do que `docs/skills/po/templates/validation-checklist.md` e `docs/skills/validador/` indicam).

Você (agente validador) NÃO decide:
- Consertar bug detectado.
- Reabrir CA de estória já `done`.
- Mudar `status` de outras estórias ou do épico para `done`.
- Aceitar `pass` sem evidência registrada.

Se durante a execução você perceber que o checklist precisa de itens que não estão no template (ex: validação específica que só faz sentido no EPIC-000), adicione e justifique. Itens adicionais não substituem os obrigatórios.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-26 atendidos.
- [ ] `validation/checklist.md` e `validation/report.md` mergeados.
- [ ] `index.json` atualizado com `validation_report` no épico.
- [ ] Esta estória com "Notas do agente" preenchida (resumo executivo do que foi validado e como).
- [ ] Frontmatter desta estória: `status: in_review` ao abrir PR do relatório; `done` após PR mergeado.
- [ ] Veredito (`approved` ou `rejected`) explícito no relatório.
- [ ] **Se aprovado:** PO em sessão seguinte marca `epic.status = done`. **Se reprovado:** PO em sessão seguinte abre estórias de correção; `epic.status` permanece `in_review`.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo específico para validação:

1. **Ao iniciar:** carregue `docs/skills/validador/SKILL.md`. Edite frontmatter desta estória e `index.json`.
2. **Durante:** executar checklist item a item; registrar evidência; não consertar nada.
3. **Se travar (ex: não consegue acessar canal de log):** `status: blocked`, registre, escale para o PO ou para o Arquiteto/Programador responsável conforme o impedimento.
4. **Ao terminar:** preencha "Notas", produza relatório final, `status: in_review`, abra PR. Após PR mergeado, `status: done`.

## Notas do agente (preenchido durante/após execução)

### Resumo executivo da validação
- 2026-05-28 — Validação INICIADA. Documentos canônicos lidos (SKILL.md, epic.md, quality-standards.md, validation-workflow.md, verdict-criteria.md, todas as 10 estórias anteriores, ADRs, DDR-001, IDR-002). Checklist criado a partir do template. **Validação bloqueada por 3 pré-condições não atendidas** — ver seção "Bloqueios encontrados". Aguarda resolução pelo PO antes de prosseguir com execução dos itens do checklist.

### Decisões tomadas durante a validação
- 2026-05-28 — Criado `validation/checklist.md` a partir do template (autorizado pela própria STORY-011: "a ser criado pelo PO... ou pelo próprio Validador a partir do template se ainda não existir").
- 2026-05-28 — STORY-011 marcada como `in_progress` e `owner_agent` definido conforme protocolo do agente.

### Descobertas
- 2026-05-28 — **CRÍTICO:** STORY-008 e STORY-009 nunca foram deployadas em homolog. Os 3 rc tags (rc.1, rc.2, rc.3 — evidência da métrica primária do EPIC-000) foram criados durante a STORY-007, ANTES dos commits de STORY-008 (`62eba0e`) e STORY-009 (`8a8d71b`). A validação da métrica primária (CA-4 da STORY-011) requer 3 deploys consecutivos com código completo do épico — o que ainda não ocorreu. Nenhuma tag foi criada após `ce0700e` (fecha STORY-009). As notas de STORY-008 e STORY-009 confirmam: "app.homolog.turni.com.br: pendente tag vX.Y.Z-rc.N".
- 2026-05-28 — **CRÍTICO:** E2E de STORY-008 e STORY-009 nunca rodaram em homolog — specs escritas, mas "execução aguarda deploy em homolog" (notas STORY-008/009). Sem CI run com E2E verde no homolog atual.
- 2026-05-28 — STORY-006 está `in_review` no index.json, mas seu único item pendente (CA-8 — setup testado em CI periódico) foi absorvido e completado pela STORY-007 (conforme notas da STORY-006: "done quando STORY-007 fechar CI verde + deploy em homologação verificado" e STORY-007 DoD: "[x] CA-8"). O status nunca foi atualizado formalmente.
- 2026-05-28 — EPIC-000 está com `status: ready` (deveria ser `in_review` para iniciar validação formal).

### Bloqueios encontrados

**BLOQUEIO 1 — PRÉ-CONDIÇÃO CRÍTICA:** STORY-006 com `status: in_review` no `index.json`.
- Causa: CA-8 (setup periódico em CI) foi absorvido pela STORY-007, que está `done`. Status de STORY-006 nunca foi atualizado.
- Resolução esperada do PO: marcar STORY-006 como `done` no `index.json` e no frontmatter da story (CA-8 foi satisfeito pelo job `scheduled-setup-test.yml` de STORY-007).

**BLOQUEIO 2 — PRÉ-CONDIÇÃO CRÍTICA:** EPIC-000 com `status: ready` (requer `in_review`).
- Resolução esperada do PO: atualizar `epics[id==EPIC-000].status` para `in_review` no `index.json` e no frontmatter `epic.md`.

**BLOQUEIO 3 — CA IMPOSSÍVEL DE VERIFICAR:** STORY-008 e STORY-009 nunca deployadas em homolog.
- Consequência: CA-4 (métrica primária — 3 deploys pós-código completo), CA-5, CA-6, CA-7, CA-10, CA-13 não podem ser verificados.
- Resolução esperada: criação de pelo menos 3 tags consecutivas (`vX.Y.Z-rc.N`) após o commit `ce0700e` (fecha STORY-009), com CI runs de deploy completo + E2E verde.

### Cobertura final
- Unitários: N/A (validação não escreve código)
- E2E: N/A (validação não escreve código)

### Links de evidência
- Relatório final: pendente (bloqueado)
- Checklist preenchido: `epics/EPIC-000-foundation/validation/checklist.md` (criado, pendente preenchimento)
- Métrica primária (3 deploys ≤ 10 min): pendente nova tag pós-STORY-009
- Screenshots homolog: pendente deploy
- Logs com request_id: pendente deploy
