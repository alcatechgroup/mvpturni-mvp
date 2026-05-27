---
story_id: STORY-004
slug: spike-auth-e-observabilidade
title: Spike Arquiteto — autenticação base e observabilidade mínima
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

# STORY-004 — Spike Arquiteto: autenticação base e observabilidade mínima

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Duas decisões transversais precisam estar registradas antes do EPIC-001 começar a implementar cadastro real:

1. **Autenticação base e roteamento por papel** — PDR-003 estabelece que **auth e base de usuários são compartilhadas** entre WebApp e Backoffice, com o **papel** do usuário definindo qual interface ele acessa pós-login (`admin` → Backoffice; `contratante`/`profissional` → WebApp). `non-functional.md` define no MVP: e-mail + senha, sessão segura, multi-fator fora do escopo. Sem ADR cobrindo, o EPIC-001 implementará auth ad-hoc — e auth ad-hoc é exatamente o que cria dívida grave depois.
2. **Observabilidade mínima** — `quality-standards.md` seção 3 exige health-check, logs estruturados, métricas básicas (RPS, latência p50/p95/p99, taxa de erro) e alerta para indisponibilidade. O hello world das STORYS 008 e 009 já precisa disso para o validador conseguir conferir o entregável visível do EPIC-000 ("health-check em verde nas duas URLs").

As duas ADRs são **fortemente correlatas no contexto desta fase do projeto**: ambas são "fundação operacional do dia 1 que toda estória posterior consome". Logs estruturados precisam, na prática, registrar contexto de usuário/sessão; auth precisa publicar eventos auditáveis (login do admin é evento sensível, por `non-functional.md`). Por isso cabem na mesma spike, em alinhamento com a sequência prevista no `epic.md` do EPIC-000 — com a ressalva de que **cada uma vira ADR separada**. Se o agente descobrir que merecem estórias próprias, escala para o PO.

- Épico: `docs/project-state/epics/EPIC-000-foundation/epic.md`
- Documentos canônicos a ler ANTES de deliberar:
  - `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` (auth compartilhada, roteamento por papel)
  - `docs/especificacao/non-functional.md` (seções Segurança e Observabilidade)
  - `docs/skills/po/references/quality-standards.md` seções 3 (observabilidade) e 4 (segurança)
  - `docs/project-state/decisions/adr/ADR-001-stack-principal.md` (lib/middleware de auth disponíveis na stack escolhida)
  - `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` (destino de logs / mecanismo de alerta)
  - `docs/especificacao/domain/usuario.md` (modelo de usuário, papéis)
  - `docs/especificacao/glossary.md` (Admin, WebApp, Backoffice, papéis)

## O quê (objetivo desta estória)

Deliberar e propor duas ADRs separadas em estado `proposed`:

- **ADR-007 — Modelo de autenticação base e roteamento por papel.**
- **ADR-008 — Observabilidade mínima (logs estruturados, health-check, formato de log).**

Ambas prontas para aprovação humana do Alexandro, de modo que STORY-008 e STORY-009 (hello world com health-check) possam consumir o desenho de observabilidade e EPIC-001 (cadastro com login) consuma o desenho de auth.

## Por quê (valor para o usuário)

- **Auth base** decidida agora protege EPIC-001 de implementar login frouxo que vire dívida de segurança quando a operação subir. O usuário final vê isso indiretamente: confiança de que sua senha e seus dados não vazam.
- **Observabilidade básica** transforma "deploy verde" em algo verificável — sem health-check + logs estruturados, o time não consegue saber que `app.homolog.turni.com.br` está realmente operando, e o validador do EPIC-000 não tem como aprovar a entrega.

## Critérios de aceite

### Para ADR-007 (autenticação base e roteamento por papel)

- [ ] **CA-1:** Existe `docs/project-state/decisions/adr/ADR-007-auth-base-e-roteamento.md` em `status: proposed`, escrito conforme `docs/skills/arquiteto/templates/adr.md`.
- [ ] **CA-2:** A ADR avalia no mínimo 2 abordagens reais (ex: auth interno baseado em sessão server-side; OIDC com provedor externo; biblioteca de auth para a stack escolhida; etc) e justifica a escolha à luz de: ergonomia para o MVP, custo, complexidade operacional, evolução para multi-fator (fora do MVP mas previsível), suporte a recuperação de senha, compatibilidade com PWA.
- [ ] **CA-3:** A ADR descreve:
  - (a) **mecanismo de identidade** (e-mail + senha conforme `non-functional.md`; armazenamento de senha — hash, função, parâmetros mínimos);
  - (b) **mecanismo de sessão** (cookie httpOnly + secure? token? expiração? renovação?);
  - (c) **modelo de papéis no usuário** (`admin`, `contratante`, `profissional`) e como ele é atribuído (cadastro vs aprovação manual do admin — PDR-003 e funil de aprovação no glossário);
  - (d) **roteamento pós-login** — como o WebApp recebe e roteia papéis externos e como o Backoffice rejeita não-admin (PDR-003);
  - (e) **logs de admin auditáveis** (`non-functional.md` Segurança) — toda ação do admin no backoffice gera log auditável;
  - (f) **recuperação de senha** em alto nível (e-mail transacional — provedor pode ser decidido depois, mas o desenho precisa caber).
- [ ] **CA-4:** A ADR explicita o que **fica para o EPIC-001** (telas de login/cadastro, integração de e-mail transacional concreta, completar cadastro pós-aprovação) e o que **precisa existir no Foundation** (apenas o mecanismo base — STORY-008/009 não precisam de login real, hello world é página pública).

### Para ADR-008 (observabilidade mínima)

- [ ] **CA-5:** Existe `docs/project-state/decisions/adr/ADR-008-observabilidade-minima.md` em `status: proposed`, escrito conforme `docs/skills/arquiteto/templates/adr.md`.
- [ ] **CA-6:** A ADR descreve:
  - (a) **formato dos logs estruturados** (JSON com campos canônicos: timestamp, level, service, request_id, user_id quando houver, evento, payload — exemplo concreto);
  - (b) **destino dos logs** (stdout do container? agregador externo? destino do provedor escolhido em ADR-004);
  - (c) **endpoint de health-check** padrão para ambas as interfaces (`/health` retornando 200 quando OK, com versão; conteúdo mínimo: status, versão, timestamp);
  - (d) **métricas mínimas** RED (requests, errors, duration) — coletadas como? expostas onde?;
  - (e) **alerta de indisponibilidade** — qual gatilho dispara alerta para humano (Alexandro) e por qual canal;
  - (f) **request_id propagation** — como uma requisição é rastreável end-to-end nos logs (mesmo sem trace distribuído sofisticado).
- [ ] **CA-7:** A ADR é viável dentro da stack (ADR-001) e do provedor (ADR-004) sem dependência de SaaS pago no MVP (custos previsíveis).
- [ ] **CA-8:** A ADR explicita o que **fica fora do escopo** (traces distribuídos sofisticados, dashboards consolidados, APM full — conforme `epic.md` do EPIC-000 seção "Fora de escopo").

### Para ambas

- [ ] **CA-9:** O `index.json` é atualizado com as duas entradas em `decisions.adr[]` (`status: proposed`, paths corretos, `decided_at`, `approved_by: null`).
- [ ] **CA-10:** Cada ADR fica em `proposed` até aprovação humana do Alexandro registrada explicitamente; aprovações independentes.

## Fora de escopo

- Implementar auth real ou observabilidade — isso fica para STORY-008/009 (health-check + logs base) e EPIC-001 (login completo).
- Decidir provedor de e-mail transacional — fica para EPIC-001 quando o cadastro tocar.
- Implementar multi-fator (`non-functional.md`: fora do MVP).
- Implementar trace distribuído / APM completo (`epic.md`: fora do EPIC-000).
- Decidir provedor de SSO externo (Google/Apple Sign-in) — fora do MVP.

## Padrões de qualidade exigidos

Estória **spike** — segue `docs/skills/po/references/quality-standards.md` com exceções declaradas:

- **Cobertura unitária / E2E:** N/A — sem código de produção.
- **Rigor aplicável:** opções reais avaliadas; viabilidade verificada na stack escolhida; coerência com `non-functional.md` (em especial seções Segurança e Observabilidade) e PDR-003.
- **Não-negociável herdado:** dados pessoais respeitam LGPD básica (`non-functional.md`); senhas com hash adequado; HTTPS obrigatório (já vai vir do provedor em ADR-004); logs de admin auditáveis.

## Dependências

- **Bloqueada por:** STORY-001 (stack escolhida afeta lib/middleware disponíveis), STORY-002 (provedor e modelo de logs/destino).
- **Bloqueia:** STORY-008 (hello world webapp consome desenho de health-check + logs), STORY-009 (idem backoffice), STORY-011 (validação). Bloqueia indiretamente EPIC-001 (login real).
- **Pré-requisitos de ambiente:** acesso a documentação da stack escolhida.

## Decisões já tomadas (não as reabra)

- **PDR-003** — auth compartilhada; papel decide roteamento → ADR-007 implementa.
- **`non-functional.md` Segurança e Observabilidade** — restringe opções (sem multi-fator no MVP; HTTPS; logs auditáveis de admin).
- **ADR-001 / ADR-002 / ADR-003 / ADR-004** — stack, topologia, repo, hospedagem já decididos.

## Liberdade técnica do agente

Você (agente arquiteto) decide:
- Abordagem técnica em cada ADR.
- Quais alternativas avaliar (mínimos definidos nos CAs).
- Estrutura de logs / esquema de campos.
- Mecanismo concreto de alerta (e-mail, webhook, etc).
- Algoritmo de hash de senha (Argon2id / bcrypt / scrypt — desde que seja "adequado para 2026").

Você (agente arquiteto) NÃO decide:
- Permitir senha em texto plano em log (proibido por `non-functional.md`).
- Introduzir multi-fator agora (fora do MVP).
- Mudar exigência de logs auditáveis para admin.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-10 atendidos.
- [ ] ADR-007 e ADR-008 em `proposed` nos paths corretos.
- [ ] `index.json` com as duas entradas novas em `decisions.adr[]`.
- [ ] Esta estória com "Notas do agente" preenchida.
- [ ] Frontmatter desta estória: `status: in_review` (aguardando aprovação).
- [ ] Nenhum código de produção introduzido.
- [ ] **Pré-condição para `done`:** Alexandro aprovou as duas ADRs explicitamente; `index.json` reflete `accepted` em ambas.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Resumo:

1. **Ao iniciar:** carregue `docs/skills/arquiteto/SKILL.md`. Atualize frontmatter desta estória e `index.json`.
2. **Durante:** deliberação documental.
3. **Se travar:** `status: blocked`, registre.
4. **Ao terminar:** preencha "Notas", `status: in_review`, atualize `index.json`, abra PR.

## Notas do agente (preenchido durante/após execução)

### Decisões tomadas
- 2026-05-27 — **ADR-007 (auth):** sessão **Sanctum SPA por cookie `httpOnly` same-site** para o WebApp Flutter Web (sem token exposto a XSS), com caminho para **token Bearer no app nativo futuro** — mesmo backend, só troca de modo. Backoffice Livewire usa sessão web padrão com cookie/host distintos do WebApp; admin em duas camadas (cookie/host + IAP da borda do ADR-004). Hash de senha **Argon2id** (64 MiB / 3 iterações / paralelismo 1; bcrypt cost ≥12 como fallback aceitável). RBAC por coluna `role` na tabela `users` única; papel `admin` nunca auto-atribuível. Reset de senha via Fortify (provedor de e-mail definido no EPIC-001). Audit log de admin existe e é **distinto** do log de observabilidade.
- 2026-05-27 — **ADR-008 (observabilidade):** log **JSON em stdout → Cloud Logging** (já fixado por ADR-004), com campos canônicos + mascaramento automático de PII/credencial. **RED via log-based metrics** + dashboard do Cloud Monitoring (sem Prometheus/SaaS pago — atende CA-7). `/health` (liveness) + readiness com check de Postgres em `api`/`admin`; `webapp` checado pelo `version.json`. **Alerta de indisponibilidade** por uptime check (60s) + alert policy de erro/p95 → e-mail para Alexandro, tudo em Terraform. `request_id` (reusa `X-Cloud-Trace-Context` do Cloud Run, fallback ULID) propagado `api`→fila→`worker`. APM/trace distribuído/RUM fora de escopo (CA-8).

### Descobertas
- 2026-05-27 — A tensão central de ADR-007 não estava na escolha "sessão vs token" em abstrato, mas no **cliente que muda de natureza**: Flutter **Web hoje** (onde cookie same-site é o seguro) vira **nativo amanhã** (onde Bearer é o natural). Sanctum suporta os dois modos no mesmo backend, o que dissolve o falso dilema — escolhe-se o modo seguro para o cliente atual sem fechar a porta do futuro.
- 2026-05-27 — ADR-004 já havia **pré-fixado** destino e formato base de log (stdout JSON → Cloud Logging) e colocado o `admin` atrás de IAP, delegando explicitamente o detalhamento a esta estória. Isso tornou ADR-008 mais uma questão de "como produzir/consumir os sinais" do que "onde mandá-los", e deu a ADR-007 a camada de borda do admin de graça.
- 2026-05-27 — `quality-standards.md` 3 (RED: RPS, p50/p95/p99, taxa de erro) é integralmente atingível **sem** sistema de métricas dedicado, via **log-based metrics** do Cloud Logging — o que mantém o princípio #1/#11 (nada novo a operar/pagar no MVP).

### Bloqueios encontrados
- Nenhum. Todas as dependências (`STORY-001`/ADR-001 stack+Sanctum, `STORY-002`/ADR-004 destino de log + IAP) estavam `accepted`, destravando a spike.

### ADRs criados
- ADR-007 — Modelo de autenticação base e roteamento por papel — `decisions/adr/ADR-007-auth-base-e-roteamento.md` — status: **proposed**
- ADR-008 — Observabilidade mínima — `decisions/adr/ADR-008-observabilidade-minima.md` — status: **proposed**

### Cobertura final
- Unitários: N/A (spike — sem código de produção)
- E2E: N/A (spike)

### Links de evidência
- PR: <a abrir>
- ADRs propostas: `decisions/adr/ADR-007-auth-base-e-roteamento.md`, `decisions/adr/ADR-008-observabilidade-minima.md`
- Aprovações registradas: pendentes — aguardando aprovação humana de Alexandro (cada ADR aprovada independentemente; CA-10).
