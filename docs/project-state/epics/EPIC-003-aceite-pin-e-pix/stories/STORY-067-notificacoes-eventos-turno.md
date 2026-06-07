---
story_id: STORY-067
slug: notificacoes-eventos-turno
title: Notificações in-app + e-mail dos eventos do turno (8 templates via STORY-020)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: true  # era false; Alexandro pediu fluxo designer→programador em 2026-06-06 (8 tipos novos de tile no centro da STORY-053)
design_screen_id: SCREEN-STORY-067-notificacoes-turno
status: in_review
owner_agent: claude-opus-4-8
created_at: 2026-06-03
updated_at: 2026-06-07
estimated_session_size: M
produces_idr: null
---

# STORY-067 — Notificações in-app + e-mail dos eventos do turno

## Contexto

EPIC-001 entregou e-mails transacionais. EPIC-002 entregou notificações in-app + e-mail para eventos da candidatura (STORY-053). Esta estória **reusa** a infraestrutura (worker `notificacoes:enviar-emails`, tabela `notificacoes`, editor de templates STORY-020) e adiciona **8 templates novos** para os eventos do turno: `turno_confirmado`, `checkin_solicitado`, `turno_ativo`, `checkout_solicitado`, `turno_finalizado`, `pix_enviado`, `turno_cancelado`, `no_show_pro`.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Documentos: STORY-053 (padrão), STORY-021 (worker), ADR-011 (provedor), PDR-012 (editor).

## O quê

8 listeners de eventos de domínio (emitidos pelas STORY-058, 062, 064, 065, 066) criam notificações na tabela `notificacoes` e enviam e-mail via worker existente. Cada notificação carrega tipo, destinatário (profissional ou contratante), payload jsonb com placeholders renderizados. Templates editáveis no Backoffice pelo admin (STORY-020) com texto-seed v1 escrito + validado pelo PO antes da estória fechar.

## Por quê

Sem notificação automática, profissional e contratante precisam ficar olhando o app constantemente — quebra a UX e elimina o valor do "tempo real" do turno. Sem editor, ajustar microcopy de aprovação vira release.

## Critérios de aceite

- [x] **CA-1:** 8 listeners criados, consumindo os eventos de domínio emitidos pelas estórias de implementação:
  - `TurnoCriado` (STORY-058) → notifica profissional ("turno_confirmado")
  - `CheckinSolicitado` (STORY-061) → notifica contratante ("checkin_solicitado")
  - `TurnoIniciado` (STORY-062) → notifica profissional ("turno_ativo")
  - `CheckoutSolicitado` (STORY-064) → notifica contratante ("checkout_solicitado")
  - `TurnoFinalizado` (STORY-064) → notifica profissional ("turno_finalizado")
  - `PixEnviado` (STORY-065) → notifica profissional ("pix_enviado")
  - `TurnoCancelado` (STORY-066) → notifica o **outro lado** ("turno_cancelado")
  - `TurnoNoShow` (STORY-066) → notifica ambos os lados ("no_show_pro")
- [x] **CA-2:** Cada notificação grava na tabela `notificacoes` (reuso da STORY-053) + envia e-mail via worker `notificacoes:enviar-emails` (reuso STORY-021/034). *(Homolog vivo: 33/33 enviadas, 0 falhas, fila vazia.)*
- [x] **CA-3:** Idempotência: chave `"{tipo}:{turno_id}"` para a maioria; `"{tipo}:{turno_id}:{geracao_pin_id}"` para checkin/checkout (já que profissional pode gerar novo PIN). Repetir o mesmo evento **não** envia 2 notificações. *(`no_show_pro` sufixa o destinatário — notifica ambos; ver Notas.)*
- [x] **CA-4:** SLA: notificação no centro in-app ≤ 60s p95 da emissão do evento (log-based metric da STORY-053 — adicionar tipos novos ao filtro). *(Filtro é genérico + label `tipo`: tipos novos entram sem mudança de infra. In-app é síncrono ao evento; e-mail medido em homolog: n=72, p50=37s, p95=60s ≤ 60s, pior caso com rajadas de teste.)*
- [x] **CA-5:** 8 `TemplateVersao` ativa criadas no editor da STORY-020 (categoria `email`) com texto-seed v1 escrito + validado pelo PO em chat (mesma disciplina STORY-053/W27). PO entrega antes da estória destravar. *(Aprovado por Alexandro em 2026-06-06, SCREEN-067 §5; seedados em homolog na rc.81.)*
- [x] **CA-6:** Wiring: e-mail consome o template correto pelo `slug` (`turno_confirmado_email`, `checkin_solicitado_email`, etc); in-app consome microcopy mais curta do mesmo `payload`. *(Teste de wiring trava o contrato payload⇆template; e-mail real verificado no Mailpit local.)*
- [x] **CA-7:** E2E em homolog: 3 cenários no Mailpit, 0 flake em 3 runs (espelha CA-12 da STORY-053 — disciplina herdada). *(Premissa Mailpit já revista na 053 — homolog é Resend; `scripts/story067-homolog-e2e.sh` 3 runs × 3 cenários, asserção in-app + entrega de e-mail conferida no banco: verde, 0 flake.)*
- [x] **CA-8:** Endpoint `GET /api/notificacoes` (reuso STORY-053) retorna notificações novas dos 8 tipos para o usuário autenticado; `POST /api/notificacoes/{id}/marcar-lida` funciona igual. *(Teste de contrato + asserção in-app ao vivo no E2E.)*
- [x] **CA-9:** Cobertura ≥ 98% no núcleo (idempotência + listeners); ≥ 80% no resto. *(Núcleo 100%; total 94,1%.)*

## Fora de escopo

- Push notifications (mobile) — `non-functional.md` exclui no MVP.
- Preferências de notificação por usuário (opt-in/out) — wishlist; padrão MVP é "tudo ligado".
- Push web (Web Push API) — fora MVP.

## Padrões de qualidade

≥ 80% / ≥ 98% no núcleo. E2E Mailpit 0 flake. SLA p95 ≤ 60s.

## Dependências

- **Bloqueada por:** STORY-058 (evento `TurnoCriado`), STORY-062 (`TurnoIniciado`), STORY-064 (`TurnoFinalizado`), STORY-065 (`PixEnviado`), STORY-066 (`TurnoCancelado`/`NoShow`). **E** texto-seed v1 do PO entregue (gargalo histórico — antecipar).
- **Bloqueia:** STORY-068 (validador verifica notificações ao vivo).
- **Pré-requisitos:** worker `notificacoes:enviar-emails` operante (herdado da W27); SMTP de homolog operante (herdado do EPIC-001).

## Decisões já tomadas

ADR-011, **ADR-018 (UUIDv7 em PKs — tabela `notificacoes` herda `id` UUIDv7 da refatoração; payload jsonb referencia `turno_id`/`profissional_id`/`contratante_id` como UUID string; chave de idempotência `"{tipo}:{turno_id}"` usa UUID)**, PDR-012, IDR de idempotência da STORY-053 (se houver).

## Liberdade técnica

Decide: estrutura interna de listeners, esquema do payload jsonb, formato dos templates (reuso máximo de helpers da STORY-053).

NÃO decide: que e-mails vão pela infra STORY-021 (decidido); que texto-seed é responsabilidade do PO (padrão herdado STORY-015/053).

## Definição de Pronto

- [x] CAs marcados; deploy verificado. *(rc.83 em homolog; smoke pós-deploy verde.)*
- [x] 8 templates `TemplateVersao` ativa carregados. *(13 no total — 5 da 053 + 8 novos.)*
- [x] PO valida cada texto-seed em chat antes da estória fechar. *(2026-06-06.)*
- [x] E2E Mailpit verde em 3 runs. *(Resend/in-app — premissa revista; 3×3, 0 flake.)*
- [x] SLA p95 verificado em homolog. *(p95=60s ≤ 60s; p50=37s; n=72.)*
- [x] `index.json` atualizado.
- [x] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Decisões tomadas
- **Fluxo designer→programador a pedido de Alexandro (2026-06-06)** — `requires_design` virou
  `true` (precedente STORY-065). SCREEN-STORY-067 é adendo leve à SCREEN-053: microcopy
  in-app (título = h1; resumo = 1ª linha do e-mail), ícone por tipo, **destino único
  `/turnos/{turno_id}`** para os 8 tipos. Texto-seed v1 + protótipo aprovados em chat
  (gate CA-5 quitado ANTES da implementação).
- **3 eventos de domínio faltavam** (`TurnoCriado`, `CheckinSolicitado`, `CheckoutSolicitado`)
  — as STORY-058/061/064 só gravavam audit log. Criados e emitidos PÓS-COMMIT pelos services
  de origem (mesmo racional do `TurnoCancelado`/066). Mudança local, dentro da intenção da CA-1.
- **`geracao_pin_id` (UUIDv7)** sorteado no PinCheckin/CheckoutService a cada geração, gravado
  na trilha e carregado no evento — materializa a chave `{tipo}:{turno_id}:{geracao_pin_id}`
  da CA-3 (re-gerar PIN re-notifica; redelivery não duplica).
- **`no_show_pro` sufixa o destinatário na chave** (`no_show_pro:{turno}:{destinatario_id}`) —
  notifica AMBOS os lados e a UNIQUE é por linha. Desvio documentado da chave-base da CA-3.
- **`motivo_texto` sempre não-vazio** no `turno_cancelado` (frase padrão quando sem motivo) —
  o renderer da 053 bloqueia placeholder vazio; `{motivo}` opcional quebraria o envio.
- **Listeners separados por responsabilidade**: `TurnoFinalizado`/`PixEnviado`/`TurnoCancelado`/
  `TurnoNoShow` ganham um 2º listener (`Notificar*`) ao lado dos de pagamento/audit da 065/066.
- Reuso integral do `CriarNotificacaoService`/worker/endpoints da 053 — zero mudança neles.

### Descobertas
- **CA-4 não exigiu mudança de infra**: a log-based metric da 053
  (`turni_<env>_notificacao_email_sla_ms`) filtra por `message="notificacao.email.sent"` e
  extrai `tipo` como label — os 8 tipos novos entram automaticamente na métrica/alerta p95.
- **Premissa "Mailpit em homolog" da CA-7 já tinha sido revista na 053**: homolog usa Resend;
  a asserção E2E é via Cloud Logging (`notificacao.email.sent`), mesmo caminho do
  `ca12-homolog-e2e.sh`. O e-mail com corpo interpolado foi verificado VIVO no Mailpit local.
- `ALTER TYPE ... ADD VALUE` não roda em transação no Postgres → migração com
  `$withinTransaction = false` + `IF NOT EXISTS`; `down()` no-op deliberado (drop de valor de
  enum não existe — o rollback real é o down da create_notificacoes_table).
- Eloquent serializa Carbon com `format()` SEM converter para UTC — teste com tz explícita
  (`America/Sao_Paulo`) gravava instante errado; fixado o instante em UTC no teste.
- `artisan test --parallel` usa bancos clonados fora do fluxo oficial e acusa falhas falsas;
  o caminho canônico é `make test-api` (pest sequencial, `turni_test`, 512M).
- `no_show_pro` fora do E2E de homolog (exige 2h de timeout do cron) — coberto por feature
  test; o cron em si foi validado na STORY-066/073.
- **Ca12EmailSmokeSeeder tinha 2 bugs latentes** (fora do DatabaseSeeder desde o fim da 053,
  ninguém percebeu): (a) `int $funcaoPrimaria` — `funcoes.id` virou UUIDv7 na W27.5; (b) sem
  `chave_pix_encrypted` no perfil → `CapturarEPagarTurnoJob` abre caso em `pix_falhas` e o
  webhook `transfer.paid` nunca nasce (sem `pix_enviado`). Ambos corrigidos; os scripts E2E
  (ca12 e s67) também mandavam `funcao_id` sem aspas no JSON.
- **Worker 1/min + latência de ingestão do Cloud Logging** subestimam asserções com janela
  por run — o script assere TOTAIS acumulados ao final (até ~10 min de espera).
- A 1ª execução do E2E deixou **3 casos "chave Pix ausente" na fila `pix_falhas`** do admin
  de homolog — lixo de teste esperado (validador da 068: ignorar/tratar manualmente).

### Bloqueios encontrados
- Nenhum. (Texto-seed — gargalo histórico — foi destravado no início da sessão com o PO.)

### IDRs criados
- Nenhum: as decisões são locais (chaves de idempotência, payload, eventos) e estão
  documentadas aqui + na SCREEN-STORY-067; nada transversal novo além do que ADR-011/053 já fixam.

### Cobertura final
- Unitários: `make test-api` 982 verdes (6.246 asserções), total 94,1%; núcleo da estória
  (8 listeners + NotificarEventoTurnoService + PayloadNotificacaoTurno + enum + eventos)
  **100%** (CA-9 ≥98% atendido). WebApp: 535 testes verdes (16 da feature de notificações).
- E2E: `scripts/story067-homolog-e2e.sh` — 3 runs × 3 cenários contra homolog **verde, 0
  flake** (asserção via caixa in-app de cada papel; entrega de e-mail conferida no banco:
  33/33 enviadas, 0 falhas, fila vazia; Pix chegou ~1 min após o checkout).
- SLA homolog (criada→enviada, n=72 incl. rajadas de teste): p50=37s, **p95=60s ≤ 60s**, max=89s.

### Links de evidência
- PR: — (workflow do projeto: commits diretos na main — 928550c, 2c5c5fb, 32fc4b8, dbee122, 2aae9e6, e1d147a, 63b77bb, de0075e + commit final)
- Pipeline: Releases v0.1.0-rc.81 (27079993808), rc.82, rc.83 — todos verdes
- Deploy de homologação: **v0.1.0-rc.83** (api/admin/webapp/fake + migrate+seed + smoke verdes)
