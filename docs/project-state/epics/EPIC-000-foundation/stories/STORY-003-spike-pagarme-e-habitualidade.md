---
story_id: STORY-003
slug: spike-pagarme-e-habitualidade
title: Spike Arquiteto — Pagar.me alto nível e estratégia de consulta de habitualidade
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

# STORY-003 — Spike Arquiteto: Pagar.me alto nível e estratégia de habitualidade

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Dois subsistemas-chave do produto exigem decisão arquitetural antes do EPIC-003 (PIN + Pix) e do EPIC-001 (cadastro com habitualidade aplicada). Ambos foram identificados como **riscos abertos** na abertura da onda (ver `docs/project-state/reports/status-2026-05-26-wave-open.md` riscos 1 e 3):

1. **Integração Pagar.me** — provedor único de pagamento (PDR-004) com fluxo de pré-autorização no aceite e captura no check-out validado, mais entrega de Pix em ≤ 15 min. Variabilidade do provedor pode atrasar o EPIC-003 se a abordagem técnica não estiver desenhada antes.
2. **Consulta de habitualidade** — regra de 2 alocações por semana no mesmo estabelecimento (PDR-002), com tratamento distinto para PF (bloqueio) e MEI/PJ (alerta + override). Exige consulta de histórico por par profissional × estabelecimento por semana — performance pode virar gargalo se a base crescer.

As duas ADRs são **heterogêneas em assunto** mas **homogêneas em propósito**: ambas são decisões de "como vamos cuidar de um subsistema crítico que afeta o coração do produto", e cada uma é pequena em escopo de deliberação (escolher abordagem entre 2–3 alternativas). Por isso, e em alinhamento com a sequência prevista no `epic.md` do EPIC-000, ficam juntas nesta spike — com a ressalva de que **cada uma vira ADR separada**. Se durante a deliberação o agente sentir que qualquer uma das duas merece estória própria por complexidade descoberta, deve escalar para o PO conforme `agent-task-format.md`.

- Épico: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Documentos canônicos a ler ANTES de deliberar:
  - `docs/project-state/decisions/pdr/PDR-002-habitualidade-no-mesmo-estabelecimento.md`
  - `docs/project-state/decisions/pdr/PDR-004-modelo-financeiro-taxa-do-contratante.md`
  - `docs/project-state/decisions/pdr/PDR-010-refresh-pix-fora-de-escopo-mvp.md` (escopo do tratamento de falha Pix)
  - `docs/especificacao/glossary.md` (termos: pré-autorização, captura, Pix de 15 min, zona verde/amarela/vermelha)
  - `docs/especificacao/non-functional.md` (SLO Pix ≤ 15 min, erro Pagar.me ≤ 1%)
  - `docs/especificacao/business-rules.md` (parâmetros habitualidade — limites semanais por tipo de pessoa)
  - `docs/especificacao/domain/compliance.md` (regras de habitualidade detalhadas)
  - `docs/especificacao/domain/pagamento.md` (modelo financeiro)
  - `docs/project-state/decisions/adr/ADR-001-stack-principal.md` (ORM / camada de query escolhida, afeta opções de consulta de habitualidade)

## O quê (objetivo desta estória)

Deliberar e propor duas ADRs separadas em estado `proposed`:

- **ADR-005 — Estratégia de integração Pagar.me em alto nível.**
- **ADR-006 — Estratégia de consulta de habitualidade.**

Ambas prontas para aprovação humana do Alexandro, de modo que EPIC-001 (habitualidade aplicada no aceite) e EPIC-003 (Pagar.me em sandbox) entrem em sprint sem dependência arquitetural pendente.

## Por quê (valor para o usuário)

Pagar.me e habitualidade são os dois subsistemas com maior risco técnico do MVP, segundo o relatório de abertura da onda. Decidir a abordagem agora — antes da implementação — reduz dramaticamente a chance de retrabalho nos épicos seguintes. Para o profissional, isso protege a promessa pública de "Pix em 15 minutos"; para o contratante, garante que a governança de habitualidade (zona verde/amarela/vermelha) funcione sem virar gargalo no aceite.

## Critérios de aceite

### Para ADR-005 (Pagar.me alto nível)

- [ ] **CA-1:** Existe `docs/project-state/decisions/adr/ADR-005-integracao-pagarme.md` em `status: proposed`, escrito conforme `docs/skills/arquiteto/templates/adr.md`.
- [ ] **CA-2:** A ADR cobre os seguintes pontos em alto nível (sem código):
  - (a) **camada anticorrupção (ACL)** — como o domínio Turni isola conceitos do Pagar.me (não vazar campos `order_id`, `charge_id` direto no modelo de turno);
  - (b) **mock local em container** — como o dev/agente roda o fluxo de pré-autorização + captura + Pix sem chamar o Pagar.me real, viabilizando ambiente local em 1 comando (`quality-standards.md` seção 2.1 + STORY-006);
  - (c) **contract testing** — como mantemos confiança de que o mock corresponde ao provedor real (qual estratégia, qual cadência);
  - (d) **idempotência** — como pré-autorização e captura são seguras contra retry (chave idempotente, modelo de erro recuperável vs fatal);
  - (e) **fluxo pré-autorização → captura → Pix** descrito em diagrama de sequência ou prosa explícita, com estados intermediários e quem aciona cada transição;
  - (f) **estratégia de erro** — como a falha Pix pós-15min é tratada (alinhada com PDR-010: fora de escopo MVP, mas registrada na trilha de auditoria);
  - (g) **observabilidade financeira mínima** — quais campos da transação Pagar.me viram log estruturado (alinha com ADR-008 a ser proposta em STORY-004).
- [ ] **CA-3:** A ADR identifica explicitamente o que **fica para o EPIC-003** (decisões de baixo nível, contratos, bibliotecas Pagar.me específicas, schema de tabela `pagamento`) e o que **precisa estar pronto antes do EPIC-001** (apenas o suficiente para o sandbox Pagar.me estar acessível no ambiente local, se algum cadastro tocar nele — em princípio não toca).

### Para ADR-006 (estratégia de habitualidade)

- [ ] **CA-4:** Existe `docs/project-state/decisions/adr/ADR-006-estrategia-habitualidade.md` em `status: proposed`, escrito conforme `docs/skills/arquiteto/templates/adr.md`.
- [ ] **CA-5:** A ADR avalia no mínimo 3 opções reais para a consulta de "alocações de um par profissional × estabelecimento na semana corrida atual": (a) query direta com índice composto e plano garantido; (b) materialized view atualizada por trigger ou job; (c) cache aplicacional invalidado por evento de aceite/cancelamento; (d) qualquer outra abordagem razoável que o arquiteto identifique.
- [ ] **CA-6:** A ADR cobre:
  - (a) abordagem escolhida e justificativa contra as descartadas (performance esperada em volume MVP, custo de implementação, custo de manutenção, fragilidade);
  - (b) como a abordagem se comporta com **volume MVP** (≤ 1k vagas/dia inicialmente — ordem de grandeza) e **volume de 1 ano** (estimativa de gargalo, gatilho de revisão);
  - (c) como a regra distinta PF (bloqueio) × MEI/PJ (alerta + override) é aplicada **na mesma consulta** ou em duas etapas;
  - (d) como a "semana corrida iniciando na segunda-feira" (PDR-002) é tratada em timezone (decisão prática: `America/Sao_Paulo`? UTC com conversão? Detalhe operacional do PDR);
  - (e) como o resultado da consulta alimenta o aceite eletrônico (override registrado fica na trilha de auditoria — PDR-002 e `domain/compliance.md`).
- [ ] **CA-7:** A ADR contempla **observabilidade da regra** — como saber, em produção, qual a taxa de override por contratante (sinal de revisão definido no PDR-002).

### Para ambas

- [ ] **CA-8:** O `index.json` é atualizado com as duas entradas em `decisions.adr[]` (`status: proposed`, paths corretos, `decided_at`, `approved_by: null`).
- [ ] **CA-9:** Cada ADR fica em `proposed` até aprovação humana do Alexandro registrada explicitamente; só então transita para `accepted`. Aprovações são independentes (uma pode ser aceita antes da outra).

## Fora de escopo

- **Implementar** integração Pagar.me ou consulta de habitualidade — isso fica para EPIC-001 (habitualidade) e EPIC-003 (Pagar.me).
- Decidir **schema de tabela** de pagamento, candidatura, turno — decisão local do Programador no épico correspondente (IDR se ganhar status durável).
- Definir **biblioteca cliente Pagar.me** específica — IDR do Programador quando implementar.
- Decidir provedor de Pagar.me — já é PDR-004 (provedor único).
- Decidir motor de penalidade por cancelamento — PDR-007 já tirou do escopo MVP.

## Padrões de qualidade exigidos

Estória **spike** — segue `docs/skills/po/references/quality-standards.md` com exceções declaradas:

- **Cobertura unitária / E2E:** N/A — não produz código de produção.
- **Rigor aplicável:** opções reais avaliadas em ambas as ADRs (mínimo 2 em ADR-005, mínimo 3 em ADR-006); trade-offs explícitos; viabilidade verificada na documentação Pagar.me (modelo de pré-autorização + captura + Pix; idempotência suportada; mock/sandbox documentado).
- **Aderência a PDRs vigentes** é parte do critério de qualidade — ADR-005 não pode contradizer PDR-004 ou PDR-010; ADR-006 não pode contradizer PDR-002 ou PDR-001.

## Dependências

- **Bloqueada por:** STORY-001 (ADR-001 escolhe ORM/camada de query que afeta opções de habitualidade; ADR-002 e ADR-003 afetam onde a integração Pagar.me roda).
- **Bloqueia:** STORY-011 (validação). Bloqueia indiretamente EPIC-001 (precisa de ADR-006 antes do aceite com regra de habitualidade) e EPIC-003 (precisa de ADR-005 antes da implementação do PIN/Pix). **Não bloqueia** STORY-006 / 007 / 008 / 009 (hello world não toca Pagar.me nem habitualidade).
- **Pré-requisitos de ambiente:** acesso à documentação pública do Pagar.me.

## Decisões já tomadas (não as reabra)

- **PDR-001** — Tipos de pessoa aceitos (PF, MEI, PJ) → afeta CA-6(c) da ADR-006.
- **PDR-002** — Habitualidade limitada a 2/semana com regra distinta PF/PJ → ADR-006 implementa, não reabre.
- **PDR-004** — Pagar.me PSP único; taxa do contratante; Pix em 15 min → ADR-005 implementa.
- **PDR-010** — Tratamento de falha Pix pós-15min fora do MVP → ADR-005 respeita escopo.
- **ADR-001 / ADR-002 / ADR-003** — stack, topologia, repo já decididos.

## Liberdade técnica do agente

Você (agente arquiteto) decide:
- Abordagem técnica em cada ADR dentro do que respeita os PDRs.
- Quais alternativas avaliar (mínimos definidos nos CAs).
- Como estruturar diagramas, prosa, exemplos.
- Cadência e mecanismo de contract testing (ADR-005).
- Estratégia de timezone para a "semana corrida" (ADR-006).

Você (agente arquiteto) NÃO decide:
- Mudar regra de habitualidade (PDR-002 trava).
- Mudar modelo financeiro (PDR-004 trava).
- Trazer escopo de épico futuro para esta spike.

Se durante a deliberação você perceber que uma das duas ADRs precisa virar estória própria por descoberta de complexidade, **pare e escale para o PO** — não force junto.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-9 atendidos.
- [ ] ADR-005 e ADR-006 em `proposed` nos paths corretos.
- [ ] `index.json` com as duas entradas novas em `decisions.adr[]`.
- [ ] Esta estória com "Notas do agente" preenchida.
- [ ] Frontmatter desta estória: `status: in_review` (aguardando aprovação).
- [ ] Nenhum código de produção introduzido (diff só de `.md` e `index.json`).
- [ ] **Pré-condição para `done`:** Alexandro aprovou as duas ADRs explicitamente; `index.json` reflete `status: accepted` em ambas.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. **Ao iniciar:** carregue `docs/skills/arquiteto/SKILL.md`. Atualize frontmatter desta estória e `index.json`.
2. **Durante:** sem código de produção. Se descobrir complexidade que merece quebrar, escale antes.
3. **Se travar:** `status: blocked`, registre. Decisões de produto escalam para o PO.
4. **Ao terminar:** preencha "Notas", `status: in_review`, atualize `index.json`, abra PR.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 2026-05-27 — **ADR-005 (Pagar.me): Opção A escolhida** — ACL no módulo de domínio `Pagamento` (interface `GatewayPagamento` + adapter Pagar.me) + **mock dedicado em container** (Docker Compose, `PAGARME_DRIVER=mock|sandbox|live`) + **contract test consumer-driven contra o sandbox no CI noturno**. Descartadas: cliente direto sem ACL + `Http::fake()` (vaza provedor no domínio; `fake` não é runtime local — fura princípio #6); sandbox como ambiente local (depende de internet — fura princípio #6). O sandbox vira **alvo do contract test**, não o ambiente de dev.
- 2026-05-27 — **ADR-005: idempotência por chave determinística** `(turno_id, operação)` (`preauth:/capture:/pix:{turno_id}`) enviada ao Pagar.me e registrada local; webhook idempotente por `event_id`. Modelo de erro recuperável (retry do worker com backoff) vs fatal (sem retry, marca falho). Falha de **Pix** segue **PDR-010**: 1 tentativa + alerta no backoffice + trilha de auditoria, sem motor de retry.
- 2026-05-27 — **ADR-006 (habitualidade): Opção A escolhida** — **query direta com índice composto** `(estabelecimento_id, profissional_id, data_inicio)` sobre Postgres, **on-demand na transação do aceite** com **lock por par×semana** para correção sob concorrência. Descartadas por antecipação (princípio #1) e risco de staleness numa regra de **bloqueio**: materialized view (Opção B — evolução com gatilho de performance) e cache aplicacional (Opção C — tende a Redis, proibido no MVP por ADR-001).
- 2026-05-27 — **ADR-006: semana corrida = seg 00:00 → dom 23:59:59.999 em `America/Sao_Paulo`**, timestamps em UTC (`timestamptz`), janela calculada no fuso de SP e convertida para UTC (evita virada de semana deslocada por fuso). Decisão PF×PJ separada da contagem: contagem única e agnóstica; decisão (bloqueio PF / alerta+override MEI-PJ por `tipo_pessoa`, PDR-001) no serviço de domínio. Override gravado **imutável** no aceite eletrônico (`{{habitualidade.override_aceito}}`) + trilha.

### Descobertas
- 2026-05-27 — A semana de habitualidade ancora no **`data_inicio` do turno/vaga** (trabalho efetivo), não na data da candidatura — confirmado em `domain/turno.md` + `domain/candidatura.md`. Alocações canceladas antes de `ativo` e `no_show_pro` **não** contam (não é trabalho realizado); o conjunto exato de status é refinamento de schema do EPIC-001 (IDR).
- 2026-05-27 — Ambas as ADRs encaixaram inteiramente nas ADRs já aceitas, sem reabrir nenhuma: ADR-002 (worker assíncrono executa as chamadas; webhook entra no `api`), ADR-004 (webhook público + Secret Manager), ADR-008 (mecanismo de log/trace/alerta já existe — estas ADRs só nomeiam os eventos: `pagamento.*`/`pix.*` e `habitualidade.*`), ADR-001/000 (Eloquent + Postgres, sem Redis). Nenhuma complexidade descoberta exigiu quebrar a spike em estórias próprias.

### Bloqueios encontrados
- Nenhum. Nenhuma decisão de produto precisou ser escalada ao PO; nenhum conflito com PDR vigente.

### ADRs criados
- ADR-005 — Estratégia de integração Pagar.me em alto nível — `decisions/adr/ADR-005-integracao-pagarme.md` — status: **accepted** (Alexandro, 2026-05-27)
- ADR-006 — Estratégia de consulta de habitualidade — `decisions/adr/ADR-006-estrategia-habitualidade.md` — status: **accepted** (Alexandro, 2026-05-27)

### Cobertura final
- Unitários: N/A (spike — sem código de produção)
- E2E: N/A (spike)

### Links de evidência
- ADRs aceitas: `decisions/adr/ADR-005-integracao-pagarme.md`, `decisions/adr/ADR-006-estrategia-habitualidade.md`
- Aprovações registradas: Alexandro aprovou ambas em chat na sessão de 2026-05-27; commit direto na `main`. Estória `done`; SPRINT-2026-W22 concluída.
