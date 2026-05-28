---
epic_id: EPIC-001
slug: cadastro-e-aprovacao
title: Cadastro e aprovação de profissional e contratante
wave: WAVE-2026-01
status: ready
owner_role: po
created_at: 2026-05-26
updated_at: 2026-05-28
target_completion: 2026-07-07  # estimativa orientativa
---

# EPIC-001 — Cadastro e aprovação

## Por que existimos (problema do usuário)

Sem usuários `ativo`, nenhum dos demais épicos funciona. Profissionais (PF, MEI ou PJ — PDR-001) e contratantes precisam conseguir entrar na plataforma de forma simples no front, com aprovação manual da equipe Turni no backoffice dentro do SLA público de 24h. O funil pós-aprovação (welcome → completar cadastro) é obrigatório para garantir que dados sensíveis e jurídicos só sejam coletados depois do filtro humano.

**Adicionalmente**: o primeiro turno real só pode acontecer com contrato eletrônico juridicamente defensável — mas a fonte e o ciclo de manutenção desse contrato **não** ficam sob responsabilidade do time de desenvolvimento. Por **PDR-012**, os templates contratuais (PF autônomo eventual e B2B PJ↔PJ) viram entidades editáveis pelo admin no backoffice, com versionamento. O EPIC-001 entrega o **texto-seed inicial** e a **interface de edição** — a evolução posterior do conteúdo jurídico fica com a equipe Turni (que pode contratar advogado externo a qualquer momento sem depender do dev). O spike jurídico/contábil **sai** do caminho crítico — vira validação posterior fora de sprint formal.

## Resultado esperado (outcome)

Ao fim deste épico, profissional (PF/MEI/PJ) e contratante (CNPJ) conseguem completar o funil `pré-cadastro → aprovação manual → welcome → completar cadastro → ativo` em homologação, com aceite eletrônico apropriado por tipo de pessoa registrado no momento da aprovação, e backoffice mínimo permitindo a equipe Turni operar a fila de aprovação dentro do SLA de 24h.

## Métrica de sucesso (como saberemos que funcionou)

- **Primária**: cadastro fim a fim em homologação (pré-cadastro → aprovação → completar → ativo) executável em ≤ 5 min para o usuário, com aprovação manual visível ao admin em ≤ 30s após submit.
- **Qualidade**: 100% dos novos cadastros aprovados geram aceite eletrônico corretamente versionado por tipo de pessoa (PF autônomo eventual ou MEI/PJ B2B↔B2B).
- **Compliance**: lista de campos coletados pré-aprovação vs pós-aprovação respeita classificação de dados (PDR-001 + `non-functional.md`).

## Entregável visível no fim do épico

- [ ] Profissional consegue se pré-cadastrar como PF, MEI ou PJ em `app.homolog.turni.com.br/cadastro`.
- [ ] Contratante consegue se pré-cadastrar em `app.homolog.turni.com.br/cadastro`.
- [ ] Admin vê fila de aprovação em `admin.homolog.turni.com.br/aprovacoes`, com filtros por tipo (profissional/contratante).
- [ ] Admin aprova com 1 clique; usuário recebe e-mail de notificação (template + provedor decidido em ADR).
- [ ] Usuário aprovado, ao logar, passa por welcome → completar cadastro → estado `ativo`.
- [ ] **Admin tem editor de templates contratuais em `admin.homolog.turni.com.br/templates`** com versionamento (PDR-012). Dois templates pré-populados com texto-seed inicial: `template_pf_autonomo_eventual` e `template_mei_pj_b2b`.
- [ ] **Aceite eletrônico anexado ao usuário no momento da aprovação referencia a versão específica do template vigente**, com placeholders renderizados (nome, documento, timestamp, IP, fingerprint).
- [ ] Mudanças posteriores no template criam nova versão; contratos passados continuam apontando para a versão original (imutabilidade do aceite).

## Fora de escopo (explicitamente)

- Login social (OAuth Google, Apple) — fica para evolução.
- Multi-fator de autenticação — fica para evolução.
- Recuperação de senha sofisticada (com perguntas de segurança, etc.) — versão simples (e-mail link) está dentro do escopo; refinamentos ficam fora.
- Edição de perfil pós-cadastro (mudança de dados, alteração de tipo de pessoa) — vira épico próprio na próxima onda.
- Multi-unidade para contratante (Enterprise) — fora do MVP.
- Validação automática de CPF/CNPJ contra Receita — PDR-001 exclui do MVP (manual pela equipe Turni).
- Exclusão de conta / LGPD direito ao esquecimento — fluxo manual no MVP (não tem UI no webapp).
- Recusa explícita pelo admin com motivo registrado — MVP apenas remove o usuário (PDR-001).
- **Spike jurídico/contábil externo (advogado + contador)** — sai do caminho crítico por PDR-012. Validação posterior é responsabilidade da equipe Turni e roda fora de sprint formal. Texto-seed inicial é escrito pelo PO com referências públicas e validado pelo Alexandro antes de produção.
- **Assinatura digital qualificada / ICP-Brasil no aceite eletrônico** — fora do MVP. O aceite registra IP + fingerprint + timestamp + versão do template, que é defensável como prova de aceite no contexto B2B / autônomo eventual brasileiro. Assinatura digital avançada vira evolução.

## Referências da especificação

- `docs/especificacao/glossary.md` — termos canônicos (tipo de pessoa, pré-cadastro, aprovação, funil, aceite eletrônico).
- `docs/especificacao/domain/usuario.md` — estados, atributos por papel, regras do funil.
- `docs/especificacao/domain/compliance.md` — aceite eletrônico por tipo de pessoa.
- `docs/especificacao/flows/cadastro-e-aprovacao.md` — fluxo ponta a ponta (a escrever durante este épico).
- `docs/especificacao/flows/welcome-e-completar-cadastro.md` — funil pós-aprovação (a escrever).
- `docs/especificacao/non-functional.md` — SLA de 24h, classificação de dados, LGPD básica.
- `docs/project-state/decisions/pdr/PDR-001-tipos-de-pessoa-aceitos.md` — base do épico.
- `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` — fila de aprovação nasce aqui.
- `docs/project-state/decisions/pdr/PDR-012-templates-contratuais-editaveis-no-backoffice.md` — define que templates são editáveis pelo admin; impacta direto o escopo deste épico.

## Dependências

- **Bloqueia**: EPIC-002, EPIC-003, EPIC-004, EPIC-005 (sem usuários `ativo`, nada acontece).
- **Bloqueado por**: EPIC-000 (Foundation) concluído.
- **Decisões arquiteturais necessárias** (cada uma vira ADR ou IDR durante o épico):
  - Modelo de dados do usuário polimórfico (`tipo_pessoa` + documento variável + atributos por papel).
  - Modelo de dados de **Template + TemplateVersao** (PDR-012): catálogo de templates com versionamento append-only; placeholders para renderização no momento do aceite.
  - Estratégia de **renderização do aceite eletrônico**: substituição de placeholders do template com dados do usuário/turno; armazenamento do resultado renderizado + ponteiro para `template_versao_id`.
  - Estratégia de aceite eletrônico (prova de timestamp, IP, fingerprint; imutabilidade após criação).
  - Provedor de e-mail transacional + ACL (segue padrão `integration-architecture.md`).
- **Não há mais spike externo bloqueante** (PDR-012 removeu essa dependência). Texto-seed dos templates é produzido pelo PO durante o épico com referências públicas + validação do Alexandro antes de produção.

## Estórias (decomposição final — Fluxo C executado em 2026-05-28)

| # | ID | Título | Tipo | Papel | Tamanho | Design? |
|---|---|---|---|---|---|---|
| 1 | STORY-012 | Spike — modelo de usuário polimórfico, funil, RBAC com ownership e audit log (ADR-009) | spike | arquiteto | M | não |
| 2 | STORY-013 | Spike — Template/TemplateVersao e AceiteEletronico imutável (ADR-010) | spike | arquiteto | S | não |
| 3 | STORY-014 | Spike — provedor de e-mail transacional + ACL (ADR-011) | spike | arquiteto | S | não |
| 4 | STORY-015 | Texto-seed dos templates contratuais (PF + MEI/PJ v1) | enablement | po | M | não |
| 5 | STORY-016 | RBAC vivo — login + roteamento por papel + funnel guard | implementation | programador | L | sim |
| 6 | STORY-017 | Pré-cadastro de Profissional (PF/MEI/PJ) no WebApp | implementation | programador | M | sim |
| 7 | STORY-018 | Pré-cadastro de Contratante no WebApp | implementation | programador | M | sim |
| 8 | STORY-019 | Fila de aprovação no Backoffice (aprovar/remover) | implementation | programador | M | sim |
| 9 | STORY-020 | Editor de templates contratuais no Backoffice | implementation | programador | M | sim |
| 10 | STORY-021 | E-mails transacionais (aprovado + lembrete + reset Fortify) | implementation | programador | M | sim |
| 11 | STORY-022 | Tela de welcome pós-aprovação no WebApp | implementation | programador | S | sim |
| 12 | STORY-023 | Completar cadastro de Profissional + AceiteEletronico | implementation | programador | L | sim |
| 13 | STORY-024 | Completar cadastro de Contratante + AceiteEletronico | implementation | programador | M | sim |
| 14 | STORY-025 | Validação final do EPIC-001 | validation | validador | M | não |

**Ordem de execução (dependências obrigatórias):**

```
STORY-012 (ADR-009) ─┐
STORY-013 (ADR-010) ─┼─► STORY-015 (texto-seed) ─► STORY-016 (RBAC vivo) ─┐
STORY-014 (ADR-011) ─┘                                                    │
                                                                          ▼
                              ┌─► STORY-017 (pré-cadastro profissional) ─┐
                              ├─► STORY-018 (pré-cadastro contratante)  ─┤
                              ├─► STORY-019 (fila aprovação) ────────────┤  podem rodar
                              ├─► STORY-020 (editor templates) ──────────┤  em paralelo
                              ├─► STORY-021 (e-mails transacionais) ─────┤
                              └─► STORY-022 (welcome) ───────────────────┘
                                            │
                                            ▼
                              ┌─► STORY-023 (completar cadastro PF/MEI/PJ + aceite) ┐
                              └─► STORY-024 (completar cadastro contratante + aceite) ┤
                                                                                      ▼
                                                                          STORY-025 (validação)
```

**Decisões PO embutidas na decomposição:**

- **Aceite eletrônico é gerado ao final do completar cadastro** (clique explícito do usuário em "Aceito e concluir cadastro" no fim das STORY-023/024), **não na aprovação do admin**. Resolve ambiguidade do texto original deste epic.md ("anexado ao usuário no momento da aprovação"): na aprovação do admin o usuário ainda não tem documento (CPF/CNPJ vem só no completar cadastro por `domain/usuario.md`), e o ato de consentimento informado é o clique do usuário com texto integral à vista. Decisão registrada em STORY-019 §Decisões já tomadas e STORY-023 §Contexto; vira PDR formal se o validador ou Alexandro pedir.
- **RBAC vivo pela primeira vez**: STORY-016 é a peça central — login + roteamento por papel + funnel guard em uma estória vertical L. Sem ela, nenhuma das outras estórias de fluxo de usuário pode entregar resultado observável.
- **Critério herdado de EPIC-000 (F-NB-1 — exercer `php artisan migrate:rollback` em homologação)** cai em STORY-016, que entrega a primeira migração com lógica de negócio (`role`, `status`, flags do funil).
- **3 ADRs novas propostas**: ADR-009 (modelo de identidade — STORY-012), ADR-010 (template versionado e aceite imutável — STORY-013), ADR-011 (provedor de e-mail + ACL — STORY-014). Cada spike concentra **uma** ADR conforme regra de `story-craft.md`.
- **STORY-015 (texto-seed) tem `target_role: po`** — primeiro caso do projeto. O PO escreve o conteúdo dos templates manualmente; nenhum agente programador envolvido.

## Validação final

Critérios em `validation/checklist.md` (criado junto com esta decomposição). Relatório do validador em `validation/report.md`.

**Definição de épico concluído**: cadastro fim a fim funcionando em homologação para os 3 tipos de pessoa do profissional + contratante; backoffice mínimo operacional (fila de aprovação **+ editor de templates contratuais**); texto-seed dos templates validado pelo Alexandro; aceite eletrônico imutável referenciando a versão ativa do template, gerado no fim do completar cadastro; RBAC vivo nas duas interfaces; audit log de admin com eventos canônicos imutáveis; e-mails transacionais entregues; relatório do validador `approved` (ou `approved_with_pending` tratado como goal atingido pelo PO, conforme precedente da STORY-011).

## Histórico

- 2026-05-26 — criado por PO durante planejamento da WAVE-2026-01.
- 2026-05-26 — ajustado por PO após PDR-012: spike jurídico/contábil sai do caminho crítico; entra estória de editor de templates no backoffice + texto-seed inicial.
- 2026-05-28 — PO executou Fluxo C: decompôs em 14 estórias (STORY-012 a STORY-025) com `status: ready`. Decomposição pronta para a SPRINT-2026-W24 (slice a definir na abertura). Status do épico passa de `draft` para `ready`. Decisão PO sobre momento do AceiteEletronico embutida nas estórias.
