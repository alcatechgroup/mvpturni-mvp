---
story_id: STORY-014
slug: spike-email-transacional-e-acl
title: Spike Arquiteto — provedor de e-mail transacional e ACL de integração (ADR-011)
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: spike
target_role: arquiteto
requires_design: false
status: done
owner_agent: arquiteto
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

- [x] **CA-1:** Existe `docs/project-state/decisions/adr/ADR-011-provedor-email-transacional-e-acl.md` em `status: accepted`, com contexto, forças, opções (5 provedores avaliados), matriz comparativa, decisão, justificativa, diagrama (fluxo de envio com ACL e fila), consequências, plano de verificação, sinais de revisão.
- [x] **CA-2:** A ADR avalia provedores com critérios explícitos (deliverability no Brasil, custo MVP, SPF/DKIM/DMARC, webhooks de bounce, suporte oficial Laravel, ergonomia operacional).
- [x] **CA-3:** A ADR define a **ACL** — interface `EnviaEmailTransacional::enviar(EmailTransacional)` com parâmetros destinatário, tipo e dados. Troca de provedor = troca de adapter; nenhuma camada acima do adapter conhece o SDK do Resend.
- [x] **CA-4:** A ADR lista as **mensagens canônicas do MVP** (`aprovacao_concedida`, `lembrete_completar_cadastro`, `recuperacao_senha`) com remetente, assunto e contrato de dados de renderização.
- [x] **CA-5:** A ADR documenta **configuração de domínio remetente** com textos exatos de SPF, DKIM, DMARC para `mail.turni.com.br`; subdomínio separado para homolog (`mail.homolog.turni.com.br`).
- [x] **CA-6:** A ADR define **Mailpit em container** como inbox visual local, coerente com o padrão `pagarme-mock` (ADR-005).
- [x] **CA-7:** A ADR documenta **tratamento de falha** — fila `database`, retry 3×, backoff exponencial, dead letter em `failed_jobs`, log `event=email.aprovacao.falhou`, alerta Cloud Monitoring (mecanismo ADR-008) para falha crítica.
- [x] **CA-8:** A ADR cita ADR-004 (Secret Manager), ADR-007 (Fortify), ADR-008 (mascaramento de destinatário), `non-functional.md` §Segurança.
- [x] **CA-9:** `index.json` atualizado com ADR-011 `accepted`, path, `decided_at: 2026-05-28`, `approved_by: Alexandro`, `source_story: STORY-014`.
- [x] **CA-10:** ADR transitou de `proposed` para `accepted` após aprovação humana de Alexandro registrada.

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

- [x] CA-1 a CA-10 passam.
- [x] ADR-011 em `status: accepted` após aprovação humana.
- [x] `index.json` atualizado.
- [x] "Notas do agente" preenchida.
- [x] Sem código de produção criado.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/arquiteto/SKILL.md`. Frontmatter: `status: in_progress` ao iniciar; `status: done` após aprovação humana.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
Lidos: STORY-014 completo, ADR-004 (GCP/Secret Manager), ADR-007 §f (Fortify/recuperação de senha), ADR-008 (log mascarado), integration-architecture.md (padrão ACL), non-functional.md §Segurança, docker-compose.yml (serviços existentes: pagarme-mock como referência), ADR-005 (padrão mock em container), ADR-009 (identidade). Template adr.md lido. Index.json estrutura verificada. Sem bloqueios de pré-requisito.

### Decisões tomadas
- **Provedor:** Resend (resend.com) — free tier 3.000/mês, DKIM automático, pacote `resend/resend-laravel` oficial.
- **ACL:** interface `EnviaEmailTransacional::enviar(EmailTransacional)` no domínio; `ResendAdapter` em homolog/prod; config SMTP para Mailpit em dev.
- **Remetente:** `no-reply@mail.turni.com.br` (prod) / `no-reply@mail.homolog.turni.com.br` (homolog) — subdomínio dedicado, não contamina raiz.
- **Inbox local:** Mailpit container (`:1025` SMTP / `:8025` UI) — coerente com padrão `pagarme-mock`.
- **Falha crítica de aprovação:** alerta via log-based metric `event=email.aprovacao.falhou` → Cloud Monitoring → e-mail para Alexandro (mecanismo ADR-008).

### Descobertas
- `integration-architecture.md` existe em `docs/skills/arquiteto/references/integration-architecture.md` — sem bloqueio de pré-requisito.
- `docker-compose.yml` já tem `pagarme-mock` como serviço — padrão de mock local consolidado e confirmado.
- ADR-009 aceita em 2026-05-28 (STORY-012 completa) — não há dependência técnica bloqueante para esta ADR.
- Mailhog está depreciado; Mailpit é o substituto moderno e correto para o projeto.

### Bloqueios encontrados
Nenhum. ADR-011 produzida sem bloqueio técnico. Aguarda aprovação humana de Alexandro.

### ADR proposta
`docs/project-state/decisions/adr/ADR-011-provedor-email-transacional-e-acl.md` — status `proposed`, aguardando aprovação de Alexandro.

### Resultado final / evidência
ADR-011 criada em `proposed`. Aguarda aprovação humana para transicionar para `accepted` e marcar STORY-014 `done`. Nenhum código de produção criado.
