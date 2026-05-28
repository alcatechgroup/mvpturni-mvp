---
story_id: STORY-001
slug: spike-stack-topologia-monorepo
title: Spike Arquiteto — stack principal, topologia e monorepo vs polirepo
epic_id: EPIC-000
sprint_id: SPRINT-2026-W22
type: spike
target_role: arquiteto
requires_design: false
status: done
owner_agent: claude-opus-arquiteto-2026-05-27
created_at: 2026-05-26
updated_at: 2026-05-27
estimated_session_size: M
---

# STORY-001 — Spike Arquiteto: stack principal, topologia e monorepo vs polirepo

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Esta é a primeira spike do EPIC-000 Foundation. Antes de qualquer linha de código de produção, o time precisa de **stack escolhida e registrada em ADR** — sem isso, todas as estórias seguintes do EPIC-000 (setup local, pipeline, hello world) ficam paradas porque ninguém sabe que linguagem/framework/ORM/test framework usar. PDR-003 exige duas interfaces (WebApp PWA mobile-first + Backoffice desktop) deployadas separadamente em homologação no fim do épico, então a escolha de stack precisa contemplar **dois deliverables independentes** desde o início.

A escolha cascateia em duas decisões fortemente correlatas (regra de "1 ADR por spike, ou 2 ADRs fortemente correlatas" em `story-craft.md`): **topologia** (monolito modular vs FE/BE/worker separados — depende da stack opinativa escolhida) e **estratégia de repositório** (monorepo vs polirepo — depende de quanta consolidação de código entre WebApp e Backoffice é desejada). As três decisões caem juntas porque decidir uma sem as outras produz inconsistência.

- Épico: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Documentos canônicos a ler ANTES de deliberar:
  - `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` (dois deploys independentes desde o MVP)
  - `docs/project-state/decisions/pdr/PDR-004-modelo-financeiro-taxa-do-contratante.md` (sinaliza necessidade de integração Pagar.me — não precisa ser resolvida aqui, mas a stack não pode tornar isso impraticável)
  - `docs/especificacao/non-functional.md` (compatibilidade, performance, observabilidade mínima)
  - `docs/especificacao/business-rules.md` (volume e perfis de carga esperados no MVP)
  - `docs/skills/arquiteto/SKILL.md` e `docs/skills/arquiteto/references/architecture-principles.md` (princípios vigentes que restringem suas opções, incluindo PostgreSQL como banco principal — formalização em STORY-005)
  - `docs/prototipo/` (entenda a natureza PWA mobile-first do WebApp)

## O quê (objetivo desta estória)

Deliberar e propor três ADRs correlatas — **ADR-001 (stack principal)**, **ADR-002 (topologia)** e **ADR-003 (monorepo vs polirepo)** — em estado `proposed`, prontas para aprovação humana do Alexandro, de modo que as estórias de implementação do EPIC-000 (a partir de STORY-006) tenham fundação técnica decidida.

## Por quê (valor para o usuário)

Esta spike não entrega valor direto a profissional nem contratante — entrega valor ao **time** (Alexandro nos 5 papéis), destravando o restante do EPIC-000. Sem stack escolhida, a STORY-006 (setup local em 1 comando) não pode começar, e sem ela, todo o pipeline e o hello world em homologação ficam impossíveis. A métrica primária do épico ("merge em main dispara deploy em ≤ 10 min, repetível em 3 merges consecutivos") só pode ser perseguida depois que essas 3 ADRs estiverem aceitas.

## Critérios de aceite

Cada item é uma asserção verificável. Spike não escreve código de produção (ver "Padrões de qualidade exigidos" abaixo); aqui o critério é a **existência e qualidade do artefato ADR** + aderência ao processo arquitetural descrito em `docs/skills/arquiteto/`.

- [ ] **CA-1:** Existe `docs/project-state/decisions/adr/ADR-001-stack-principal.md` em `status: proposed`, escrito conforme `docs/skills/arquiteto/templates/adr.md`, contendo: contexto, opções consideradas (mínimo 2), decisão, justificativa, consequências (positivas, negativas/trade-offs, para o time técnico), sinais de revisão. A ADR cobre linguagem, framework opinativo, ORM/camada de query e ferramenta de teste (unitário + E2E).
- [ ] **CA-2:** Existe `docs/project-state/decisions/adr/ADR-002-topologia.md` em `status: proposed`, decidindo entre **monolito modular** e **separação inicial FE/BE/worker**, justificando a escolha à luz da stack escolhida em ADR-001, do volume MVP esperado (`docs/especificacao/business-rules.md`) e dos NFRs (`docs/especificacao/non-functional.md`).
- [ ] **CA-3:** Existe `docs/project-state/decisions/adr/ADR-003-monorepo-vs-polirepo.md` em `status: proposed`, decidindo a estratégia de repositório para servir **WebApp + Backoffice** (exigência de PDR-003), declarando como código comum (design tokens, regras de domínio) será compartilhado entre as duas interfaces sem duplicação descontrolada.
- [ ] **CA-4:** As três ADRs são internamente coerentes — a topologia escolhida em ADR-002 é executável na stack de ADR-001, e a estratégia de repositório de ADR-003 não contradiz a topologia. Eventuais tensões entre elas estão declaradas e justificadas.
- [ ] **CA-5:** Cada ADR cita explicitamente: (a) o PDR que a motivou (quando aplicável — PDR-003 para ADR-003); (b) por que ela respeita os princípios vigentes em `docs/skills/arquiteto/references/architecture-principles.md` e (c) a exigência herdada de TDD + E2E + automação (a stack escolhida precisa ter ferramentas maduras para isso).
- [ ] **CA-6:** O `index.json` é atualizado com as três entradas em `decisions.adr[]` (status `proposed`, paths corretos, `decided_at` preenchido com a data de proposta, `approved_by` ainda em `null`).
- [ ] **CA-7:** As três ADRs ficam em `proposed` até aprovação humana do Alexandro registrada explicitamente (campo `approved_by` + data). Se Alexandro pedir revisão antes de aprovar, a ADR é editada e mantida em `proposed`; só vai para `accepted` após o "ok" registrado.

## Fora de escopo

- Decidir **provedor cloud / IaC / mecanismo concreto de deploy** — isso é STORY-002.
- Decidir **estratégia de integração Pagar.me / estratégia de habitualidade** — isso é STORY-003.
- Decidir **autenticação e observabilidade mínima** — isso é STORY-004.
- Decidir formalmente **PostgreSQL como banco principal** — é STORY-005 (ADR-000 retroativo). Esta spike **assume** PostgreSQL como dado e desenha a stack em volta dele.
- Implementar qualquer linha de código de produção. Spike não codifica — propõe ADR.
- Escolher bibliotecas específicas dentro do framework (ex: lib de validação, lib de logs). Essas decisões são locais do Programador via IDR quando surgirem.

## Padrões de qualidade exigidos

Esta estória é **spike** (`type: spike`, `target_role: arquiteto`). Segue os padrões em `docs/skills/po/references/quality-standards.md` com as exceções explícitas abaixo (autorizadas pela seção "Spikes e cobertura de testes" de `docs/skills/po/references/story-craft.md`):

- **Cobertura unitária:** N/A — spike não produz código de produção.
- **Testes E2E:** N/A — spike não produz fluxo de usuário.
- **Disciplina de qualidade aplicável:** rigor argumentativo da ADR (opções reais consideradas, trade-offs explícitos, sinais de revisão), aderência ao template do Arquiteto, coerência com PDRs vigentes, viabilidade técnica das opções escolhidas verificada via leitura de docs oficiais / experiência prévia. **Decisão por palpite, sem ao menos 2 opções reais avaliadas, é motivo de rejeição da ADR.**
- **Stack escolhida em ADR-001 obrigatoriamente:** suporta TDD + E2E maduros (ferramentas com comunidade ativa) e tem caminho viável para automação completa (ambiente local em 1 comando, CI/CD, IaC) — não pode ser escolha que torne os princípios não-negociáveis impraticáveis.

## Dependências

- **Bloqueada por:** nenhuma. Esta é a primeira estória do EPIC-000.
- **Bloqueia:** STORY-002 (hospedagem depende de saber a stack para validar viabilidade no provedor), STORY-006 (setup local depende da stack), STORY-007 (pipeline depende da stack), STORY-008 (hello world webapp), STORY-009 (hello world backoffice). Também bloqueia indiretamente STORY-011 (validação) já que tudo encadeia.
- **Pré-requisitos de ambiente:** nenhum. Spike é deliberação documental.

## Decisões já tomadas (não as reabra)

- **PDR-003** — Duas interfaces (WebApp + Backoffice) com deploy independente desde o MVP → `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md`. ADR-003 (monorepo vs polirepo) **precisa** suportar isso.
- **PDR-004** — Pagar.me como PSP único; Pix em 15 min → `docs/project-state/decisions/pdr/PDR-004-modelo-financeiro-taxa-do-contratante.md`. ADR-001 não pode escolher stack que torne a integração Pagar.me impraticável.
- **PDR-011** — Escopo da WAVE-2026-01 → `docs/project-state/decisions/pdr/PDR-011-escopo-da-wave-2026-01.md`. Stack escolhida precisa ser razoável para entregar os 6 épicos da onda.
- **Princípio arquitetural #3 vigente** — PostgreSQL como banco principal (formalização retroativa em STORY-005 / ADR-000). ADR-001 desenha a stack em volta de PostgreSQL.
- **Princípios não-negociáveis do PO** — TDD + E2E + automação + entrega em produção desde o dia 1. ADR-001 precisa escolher stack que torne isso natural, não acrobático.

## Liberdade técnica do agente

Você (agente arquiteto) decide:
- Quais opções de stack avaliar (no mínimo 2 reais por ADR, com avaliação justificada).
- Como estruturar argumentos de trade-off dentro do template ADR.
- Que critérios técnicos pesar (maturidade da comunidade, ergonomia de TDD, integração com PostgreSQL, ergonomia de PWA mobile-first, footprint de deploy, etc).
- Sinais de revisão de cada ADR (gatilhos de "se X acontecer, reabrimos").

Você (agente arquiteto) NÃO decide:
- **PostgreSQL como banco** — já vigente como princípio; STORY-005 só formaliza.
- **Existir duas interfaces** — PDR-003 já decidiu; ADR-003 só implementa.
- Padrões de qualidade exigidos pelo PO (TDD, E2E, automação, cobertura).
- **Hospedagem / IaC / Pagar.me / autenticação / observabilidade** — outras spikes do EPIC-000.

Se durante a deliberação você perceber que uma decisão de produto é necessária e não há PDR cobrindo, **pare e registre** na seção "Notas do agente" — escale para o PO.

## Definição de Pronto (DoD)

- [ ] Todos os critérios de aceite (CA-1 a CA-7) passam.
- [ ] Três ADRs criadas em `docs/project-state/decisions/adr/` com `status: proposed`, conforme template do Arquiteto.
- [ ] `index.json` atualizado com as três entradas em `decisions.adr[]`.
- [ ] Esta estória atualizada com a seção "Notas do agente" preenchida (decisões consideradas, opções descartadas com razão, riscos identificados).
- [ ] Frontmatter desta estória atualizado: `status: in_review` (aguardando aprovação humana de Alexandro nas 3 ADRs).
- [ ] Não há código de produção introduzido por esta estória (verificável por diff: apenas arquivos `.md` e `index.json`).
- [ ] **Pré-condição para `status: done`:** Alexandro aprovou as 3 ADRs explicitamente (cada uma com `approved_by` preenchido) e o `index.json` reflete `status: accepted` em todas elas.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Em resumo:

1. **Ao iniciar:** carregue a skill `arquiteto` (`docs/skills/arquiteto/SKILL.md`). Edite o frontmatter desta estória: `status: in_progress`, `owner_agent: <seu identificador/sessão>`, `updated_at: <hoje>`. Atualize `index.json` também.
2. **Durante:** mantenha TaskList interna; deliberação documental, sem código de produção. Se descobrir que uma das 3 ADRs precisa ser quebrada em duas para caber bem, **converse com o PO antes** — não invente escopo.
3. **Se travar:** edite frontmatter para `status: blocked` e descreva o bloqueio em "Notas do agente". Não invente decisão de produto.
4. **Ao terminar:** preencha "Notas do agente" abaixo, marque `status: in_review`, atualize `index.json`, abra PR. **O `status: done` só vem depois da aprovação humana das 3 ADRs.**

## Notas do agente (preenchido durante/após execução)

> Esta seção é a memória da estória. Preencha conforme executa. Não apague o que você escreveu — adicione.

### Decisões tomadas
- 2026-05-27 — **Direção de stack definida pela liderança técnica (Alexandro), não pelo agente.** Em sessão de deliberação, o agente apresentou 3 pacotes de stack (Laravel+Livewire+Flutter; TypeScript ponta a ponta NestJS+React; Django+React). Alexandro escolheu **Laravel (backend) + Livewire (backoffice) + Flutter (WebApp, web no MVP e nativo no futuro)**, com diretriz de **seguir o ecossistema/práticas Laravel sempre que possível** e usar **versões mais recentes**. → ADR-001.
- 2026-05-27 — **Versões mais recentes verificadas via web (maio/2026):** PHP 8.5.6 (8.4 ainda em suporte ativo), Laravel 13.6, Livewire 4.3, Flutter 3.44 / Dart 3.12. Baseline a fixar em STORY-006.
- 2026-05-27 — **Topologia (Q1 ao Alexandro):** escolhida **dois deploys Laravel** (`api` público + `admin` Livewire em rede restrita) sobre um **domínio modular compartilhado** + worker, honrando a segregação de superfície do PDR-003. Opção descartada: monolito Laravel único (api+admin no mesmo deploy) — relaxaria PDR-003; mantida como alternativa barata de retomar se o overhead de 2 deploys incomodar. → ADR-002.
- 2026-05-27 — **Repositório:** **monorepo poliglota único** (apps/api, apps/admin, apps/webapp Flutter, packages/domain PHP, packages/design-tokens, contracts/OpenAPI). Opção descartada: polirepo — cerimônia de versionar/publicar pacotes internos é desproporcional para time de 1–3 pessoas. → ADR-003.
- 2026-05-27 — **Topologia "dois deploys" ≠ microsserviços:** registrado explicitamente em ADR-002 que o domínio é único (um Postgres, um package), e api/admin são camadas finas de entrega (comunicação in-process, nunca por rede). Coerência CA-4 garantida.

### Descobertas
- 2026-05-27 — **Risco de RNF do Flutter Web (relevante para PO e Programador).** Flutter Web (CanvasKit/Skwasm) tem carga inicial pesada e acessibilidade baseada em canvas — ameaça os SLOs públicos `FCP em 3G ≤ 5s` e `leitor de tela nas principais interações` (`non-functional.md`). **Decisão de tratamento (Q2 ao Alexandro):** aceitar e documentar o trade-off com sinais de revisão; validação empírica no hello-world (STORY-008), **não** via spike prévio. Se o FCP 3G furar e a otimização não fechar o gap, ADR-001 prevê reabrir o renderer/abordagem (ex.: PWA leve em DOM para web, Flutter só no nativo futuro). **Programador da STORY-008 deve medir FCP 3G e a11y como parte do hello-world.**
- 2026-05-27 — **Preocupação explícita do lead com "versão velha" do app web.** Tratada em ADR-001 (Plano de verificação): `index.html`+service worker com `Cache-Control: no-cache`, assets com hash imutável, endpoint `version.json` + aviso "nova versão disponível", e gate de versão mínima (`426 Upgrade Required`) nos fluxos de PIN/pagamento. Pode virar ADR Frontend/PWA dedicado depois.
- 2026-05-27 — **Stack poliglota (PHP + Dart) limita o reuso entre interfaces.** WebApp (Dart) e Backoffice (PHP/Livewire) não compartilham código de runtime — só contrato de API (OpenAPI → cliente Dart) e design tokens (fonte única gerando tema Dart + CSS). O reuso forte de domínio fica entre `api` e `admin` (ambos PHP). Declarado em ADR-001 e ADR-003.

### Bloqueios encontrados
- 2026-05-27 — Nenhum bloqueio. Direção de produto/stack estava no domínio da liderança técnica (Alexandro), que decidiu na sessão. Não houve necessidade de escalonar decisão de produto sem PDR.

### ADRs criados
- ADR-001 — Stack principal (Laravel + Livewire + Flutter) — `decisions/adr/ADR-001-stack-principal.md` — status: **accepted** (Alexandro, 2026-05-27)
- ADR-002 — Topologia (monolito modular, api + admin + worker, domínio compartilhado) — `decisions/adr/ADR-002-topologia.md` — status: **accepted** (Alexandro, 2026-05-27)
- ADR-003 — Monorepo poliglota único — `decisions/adr/ADR-003-monorepo-vs-polirepo.md` — status: **accepted** (Alexandro, 2026-05-27)

### Cobertura final
- Unitários: N/A (spike)
- E2E: N/A (spike)

### Links de evidência
- PR: <a abrir>
- ADRs (todas `accepted`): `decisions/adr/ADR-001-stack-principal.md`, `decisions/adr/ADR-002-topologia.md`, `decisions/adr/ADR-003-monorepo-vs-polirepo.md`
- Aprovações registradas: Alexandro aprovou as 3 ADRs em chat (sessão de 2026-05-27); `approved_by: Alexandro` em cada ADR e no `index.json`. Estória movida para `status: done`.

### Riscos identificados (resumo para o PO/Programador)
- **Alto:** Flutter Web pode furar FCP 3G ≤ 5s e/ou a11y de leitor de tela (SLO público). Mitigação: medir em STORY-008; sinais de revisão em ADR-001.
- **Médio:** overhead de manter 2–3 deploys Laravel (api/admin/worker) e path filters de CI corretos (STORY-002/007).
- **Médio:** disciplina de auto-atualização do WebApp para evitar "versão velha" — padrão definido, precisa ser implementado fielmente.
- **Baixo:** duas linguagens (PHP + Dart) — dois toolchains/suítes de teste.
