---
story_id: STORY-014
slug: spike-email-transacional-e-acl
title: Spike Arquiteto — provedor de e-mail transacional e ACL de integração (ADR-011)
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: spike
target_role: arquiteto
requires_design: false
status: ready
owner_agent: null
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: S
---

# STORY-014 — Spike Arquiteto: provedor de e-mail transacional e ACL

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

O EPIC-001 introduz a primeira necessidade real de e-mail transacional: **notificação de aprovação** ("seu cadastro foi aprovado — clique aqui para continuar"), **lembrete de completar cadastro** quando usuário liberado deixa o funil parado por mais de N horas, e **recuperação de senha** (Fortify, decidido em ADR-007 §f — esta ADR formaliza o **provedor concreto**). ADR-007 §f explicitamente declarou: "O envio usa o `Mail` do Laravel; o **provedor de e-mail transacional concreto fica para o EPIC-001** (`non-functional.md`/escopo desta estória) — o desenho apenas garante que cabe (driver de mail plugável)". `integration-architecture.md` (referenciada em epic.md §Dependências) padroniza ACL para integrações externas — qualquer provedor que escolhermos precisa de Anti-Corruption Layer entre o domínio Turni e o SDK do provedor.

Sem ADR: STORY-021 (e-mails transacionais) decide o provedor no PR; falha sai ad-hoc; SPF/DKIM/DMARC ficam soltos; trocar de provedor depois vira refactor profundo na camada de domínio.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de deliberar:
  - `docs/project-state/decisions/adr/ADR-007-auth-base-e-roteamento.md` §f (Fortify, throttling, link assinado, recuperação de senha)
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` (GCP, Secret Manager — provedor escolhido deve caber neste cenário)
  - `docs/especificacao/non-functional.md` §Segurança (segredos, HTTPS, LGPD básica)
  - `docs/skills/arquiteto/references/integration-architecture.md` (padrão de ACL para integrações externas — deve existir; se ausente, registre como descoberta)
  - `docs/skills/arquiteto/SKILL.md`

## O quê (objetivo desta estória)

Deliberar e propor **ADR-011 — provedor de e-mail transacional e Anti-Corruption Layer**, em estado `proposed`, cobrindo:

1. **Provedor escolhido** com no mínimo 3 opções avaliadas (sugestões: SendGrid, Mailgun, Amazon SES, Postmark, Resend, Brevo). Critérios: deliverability para o Brasil, plano gratuito ou inicial barato compatível com volume MVP (~centenas de e-mails/mês), facilidade de configurar SPF/DKIM/DMARC para `turni.com.br`, suporte a templates (ou irrelevância de tal recurso para o desenho), webhook de bounce/complaint (importante para limpeza de lista futura), custo de saída fácil.
2. **ACL** — interface estável no domínio Turni (`packages/domain`) que abstrai o SDK do provedor; troca de provedor é mudança de **adapter**, não de domínio.
3. **Mensagens canônicas do MVP**: lista dos e-mails que o EPIC-001 vai enviar — `aprovacao_concedida`, `lembrete_completar_cadastro`, `recuperacao_senha` (Fortify). Cada uma com remetente, assunto, corpo (placeholder de conteúdo — texto definitivo fica para STORY-021), template visual de base (se aplicável — DDR-001 pode ditar identidade).
4. **Configuração de domínio remetente**: `no-reply@turni.com.br` (ou subdomínio dedicado — sua decisão) com SPF, DKIM, DMARC documentados. Em homolog: subdomínio separado (ex.: `homolog.turni.com.br` ou `mail-homolog.turni.com.br`) para não contaminar reputação do principal.
5. **Estratégia de teste local**: em dev, e-mails vão para um **inbox visual** (Mailpit/Mailtrap/log driver) — sua escolha, alinhada com o padrão de mock do Pagar.me (`pagarme-mock` em container).
6. **Tratamento de falha**: o que acontece quando o provedor rejeita ou está fora — fila com retry (Laravel já tem driver `database` da fila configurado por ADR-002), backoff, dead letter, log estruturado, e — para falhas críticas no fluxo de aprovação — alerta ao admin.

A ADR é aceita por Alexandro antes da STORY-021 (e-mails transacionais).

## Por quê (valor para o usuário)

Esta spike entrega valor ao **time** — destrava STORY-021. Indiretamente, destrava entrega de valor real ao usuário: sem e-mail confiável de aprovação, o profissional/contratante aprovado **não fica sabendo** que pode entrar — quebra o funil, derruba a promessa de SLA de 24h registrada em `non-functional.md`. A escolha precisa ser barata, simples e reversível — não é peça crítica de longo prazo.

## Critérios de aceite

Spike não produz código de produção. Critério é a **existência e qualidade do artefato ADR**.

- [ ] **CA-1:** Existe `docs/project-state/decisions/adr/ADR-011-provedor-email-transacional-e-acl.md` em `status: proposed`, com contexto, forças, opções (mínimo 3 provedores reais avaliados), matriz comparativa, decisão, justificativa, diagrama (fluxo de envio com ACL e fila), consequências, plano de verificação, sinais de revisão.
- [ ] **CA-2:** A ADR avalia provedores com critérios explícitos (deliverability no Brasil, custo MVP, SPF/DKIM/DMARC, webhooks de bounce, suporte oficial Laravel, ergonomia operacional).
- [ ] **CA-3:** A ADR define a **ACL** — interface canônica do domínio (`SendTransactionalEmail` ou nome equivalente, com parâmetros mínimos: destinatário, tipo de mensagem, dados de renderização). Troca de provedor = troca de adapter; nenhuma camada acima do adapter conhece o SDK do provedor.
- [ ] **CA-4:** A ADR lista as **mensagens canônicas do MVP** (`aprovacao_concedida`, `lembrete_completar_cadastro`, `recuperacao_senha`) com remetente, assunto, contrato de dados de renderização. Conteúdo textual definitivo é de STORY-021; aqui só o contrato.
- [ ] **CA-5:** A ADR documenta **configuração de domínio remetente** com SPF, DKIM, DMARC (textos exatos dos registros DNS), separação dev/homolog/prod e cuidado para não contaminar reputação do domínio principal.
- [ ] **CA-6:** A ADR define **estratégia de teste local** — inbox visual em container ou log driver — coerente com a filosofia de mocks locais já estabelecida (ADR-005 para Pagar.me).
- [ ] **CA-7:** A ADR documenta **tratamento de falha** — fila com retry, backoff, dead letter, log estruturado conforme ADR-008, e (para falhas críticas no fluxo de aprovação) alerta ao admin via canal já existente (e-mail/Slack/Cloud Monitoring — sua decisão, justificada).
- [ ] **CA-8:** A ADR cita ADR-004 (Secret Manager — credenciais do provedor), ADR-007 (Fortify), ADR-008 (log estruturado e mascaramento — destinatário não vai em log claro), e `non-functional.md` §Segurança (segredos não em código).
- [ ] **CA-9:** `index.json` atualizado com a entrada em `decisions.adr[]` para ADR-011 (`proposed`, path, `decided_at`, `approved_by: null`, `source_story: STORY-014`).
- [ ] **CA-10:** ADR fica em `proposed` até aprovação humana do Alexandro registrada.

## Fora de escopo

- Implementar o envio em código — STORY-021.
- Definir conteúdo textual final dos e-mails — STORY-021 (corpo redacional + DDR-001 para visual, se aplicável).
- Lista de e-mails **fora** do EPIC-001 (notificação de match, lembrete de check-in, etc.) — outros épicos.
- Configurar SMS / notificação push — fora do MVP.
- Implementar painel de gestão de e-mails enviados — fora do MVP.

## Padrões de qualidade exigidos

Spike. Segue `quality-standards.md` com as exceções de "Spikes e cobertura de testes":

- **Cobertura unitária / E2E:** N/A.
- **Disciplina aplicável:** rigor argumentativo, mínimo 3 provedores avaliados, trade-offs explícitos.
- **Compatível com:** GCP/Cloud Run (ADR-004), Secret Manager para credenciais (ADR-004), fila `database` do Laravel (ADR-002), Sanctum/Fortify (ADR-007), log mascarado (ADR-008).
- **Segurança:** credenciais do provedor **nunca** em código; vão em Secret Manager. Domínio remetente com SPF/DKIM/DMARC documentados.

## Dependências

- **Bloqueada por:** nenhuma técnica direta. Pode rodar em paralelo com STORY-012 e STORY-013.
- **Bloqueia:** STORY-021 (e-mails transacionais).
- **Pré-requisitos de ambiente:** nenhum.

## Decisões já tomadas (não as reabra)

- **ADR-004** — GCP/Cloud Run + Cloud SQL; Secret Manager para credenciais.
- **ADR-007** — Fortify para recuperação de senha, com link assinado e throttling.
- **ADR-008** — Log JSON estruturado com mascaramento.
- **ADR-002** — Fila `database` do Laravel (sem Redis no MVP).
- **`non-functional.md`** — HTTPS obrigatório; segredos via cofre.

## Liberdade técnica do agente

Você decide:
- Provedor concreto (entre os 3+ avaliados) com justificativa.
- Nome da interface da ACL e parâmetros.
- Subdomínio remetente (ex.: `no-reply@turni.com.br` vs `no-reply@mail.turni.com.br`).
- Ferramenta de inbox local (Mailpit, MailHog, log driver) — coerente com docker-compose existente.
- Estratégia de retry e dead letter (números de tentativas, backoff).

Você NÃO decide:
- Reabrir ADR-004 (provedor cloud) ou ADR-007 (Fortify).
- Conteúdo textual final dos e-mails (STORY-021).
- Implementação em código (STORY-021).

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-10 passam.
- [ ] ADR-011 em `status: accepted` após aprovação humana.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.
- [ ] Sem código de produção criado.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/arquiteto/SKILL.md`. Frontmatter: `status: in_progress` ao iniciar; `status: done` após aprovação humana.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
(a preencher)

### Decisões tomadas
(a preencher)

### Descobertas
(a preencher)

### Bloqueios encontrados
(a preencher)

### ADR proposta
(a preencher — link após criação)

### Resultado final / evidência
(a preencher)
