---
story_id: STORY-053
slug: notificacoes-candidatura-in-app-email
title: Notificações da candidatura — in-app + e-mail (recebida, edição material, retirada por edição, cancelamento)
epic_id: EPIC-002
sprint_id: SPRINT-2026-W27
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-053-notificacoes  # caixa in-app + e-mails transacionais
status: ready
owner_agent: null
created_at: 2026-06-01
updated_at: 2026-06-01
estimated_session_size: M
produces_idr: null
---

# STORY-053 — Notificações da candidatura (in-app + e-mail)

> **Para o agente:** consome 3 eventos de domínio (`CandidaturaEnviada`, `VagaEditadaMaterialmente`, `VagaCancelada`) e emite 5 notificações: (1) contratante recebe e-mail + in-app quando profissional candidata; (2) profissional recebe e-mail + in-app quando vaga é editada materialmente; (3) profissional recebe e-mail quando vaga é cancelada (cancelamento já notifica no momento da ação UI, mas o e-mail garante para quem fechou o app). Reusa a infraestrutura de e-mail da STORY-021 (EPIC-001).

## Contexto

Sem notificação ao contratante, a métrica primária do épico ("contratante recebe primeira candidatura em ≤ 2h") fica invisível — contratante teria que abrir o app e ficar dando refresh no painel. Sem notificação ao profissional na edição, candidato confirma vaga que não viu mudar — quebra de PDR-009. Sem notificação no cancelamento, candidato chega no estabelecimento e a vaga não existe.

- Épico: `epics/EPIC-002-vaga-feed-e-candidatura/epic.md`
- Documentos: PDR-009 (diff antes/depois na notificação), `domain/candidatura.md`, STORY-021 (provedor de e-mail + templates SPF/DKIM/DMARC verdes), STORY-014 (Anti-Corruption Layer e-mail).

## O quê

Listener para os 3 eventos de domínio que (a) cria registros em uma tabela `notificacoes` (nova) com `tipo`, `destinatario_id`, `vaga_id`, `candidatura_id`, `payload jsonb`, `lida_em`, `criada_em`; (b) dispara worker (reusa Cloud Run Job da STORY-034) que processa fila e envia e-mail via provedor de STORY-014/021; (c) endpoint `GET /api/notificacoes` para o WebApp mostrar caixa in-app + `POST /api/notificacoes/{id}/marcar-lida`. 5 templates de e-mail novos no editor de templates (STORY-020) — texto-seed v1 do PO entra como TemplateVersao ativo.

## Por quê

Fecha a malha do EPIC-002: cada ação relevante chega a quem precisa saber, automaticamente. Sem isto, o sistema funciona mas a comunicação depende do usuário fazer poll manual.

## Critérios de aceite

- [x] **CA-1:** Migração cria tabela `notificacoes` com colunas listadas acima; índice em `(destinatario_id, lida_em, criada_em DESC)`.
- [x] **CA-2:** Listener `App\Listeners\HandleCandidaturaEnviada` consome `CandidaturaEnviada` → insere 1 linha em `notificacoes` para o contratante dono da vaga com `tipo='candidatura_recebida'`, payload = `{ profissional_nome, profissional_score, vaga_id }`. Audit log `notificacao.criada`.
- [x] **CA-3:** Listener `HandleVagaEditadaMaterialmente` consome `VagaEditadaMaterialmente` → insere N linhas em `notificacoes` (1 por candidato pendente) com `tipo='vaga_editada_material'`, payload = `{ vaga_id, diff: { campo: { antes, depois } } }`.
- [x] **CA-4:** Listener `HandleVagaCancelada` consome `VagaCancelada` → insere N linhas em `notificacoes` (1 por candidato pendente) com `tipo='vaga_cancelada'`, payload = `{ vaga_id, vaga_funcao, vaga_data_inicio }`.
- [x] **CA-5:** Worker (Cloud Run Job + Scheduler 1/min, reusa STORY-034) pega `notificacoes` não enviadas por e-mail (marca via campo `enviada_email_em`), gera e-mail pelo template ativo correspondente (5 novos: `candidatura_recebida_contratante`, `vaga_editada_material_profissional`, `vaga_cancelada_profissional`, `vaga_editada_material_candidatura_mantida_contratante` — confirma envio, `vaga_editada_material_candidatura_retirada_contratante` — retirada por edição), envia via provedor de STORY-021. Falha de envio: retry com backoff (3 tentativas), depois marca como `falha_envio` e alerta no log.
- [x] **CA-6:** 5 templates novos criados no editor (STORY-020), texto-seed v1 do PO (Alexandro) carregado como `TemplateVersao` ativa (mesmo padrão do EPIC-001 STORY-015). Variáveis disponíveis em cada template estão documentadas no editor.
- [x] **CA-7:** Endpoint `GET /api/notificacoes?lidas=false` retorna últimas 50 notificações não lidas do usuário autenticado, ordem `criada_em DESC`. `POST /api/notificacoes/{id}/marcar-lida` marca; `POST /api/notificacoes/marcar-todas-lidas` atalho.
- [x] **CA-8:** WebApp: badge no app shell mostra contagem de não-lidas; clique abre painel lateral com lista; clicar em notificação navega para a vaga relevante e marca como lida.
- [ ] **CA-9:** SLA: notificação criada → e-mail enviado em ≤ 60s p95 (worker rodando 1/min). Métrica observada em homolog via log-based metric.
- [x] **CA-10:** Privacidade: e-mail de candidatura recebida ao contratante mostra nome + score (não CPF, não telefone — esses só aparecem após aceite no EPIC-003). Aliasing/PII conforme `business-rules.md` (não há nada novo para o EPIC-002).
- [x] **CA-11:** Cobertura: listeners + worker + endpoints ≥ 95%; widget in-app ≥ 80%. Testes: cada listener com evento mock; worker com 5 notificações pendentes; retry após falha; endpoints com filtros.
- [ ] **CA-12:** E2E: profissional candidata → contratante recebe e-mail em inbox de teste (Mailpit em homolog) + notificação aparece no badge ao recarregar. Contratante edita vaga → 2 candidatos recebem e-mail + in-app. Contratante cancela → candidatos recebem e-mail. 0 flake em 3 runs.

## Fora de escopo

- Push notifications nativas (FCM/APNs/Web Push) — onda 2.
- Preferências do usuário (quero/não quero e-mail) — fica como wishlist; default é receber tudo do funil.
- Templates segmentados por persona (Member Start vs. Enterprise) — fora do MVP.
- Reset de senha / e-mails de identidade — já em STORY-021.

## Padrões de qualidade

≥ 95% listeners/worker/endpoints, ≥ 80% widget, E2E verde com 3 cenários, SLA ≤ 60s observado.

## Dependências

- **Bloqueada por:** STORY-021 (provedor de e-mail + SPF/DKIM/DMARC), STORY-020 (editor de templates), STORY-034 (Cloud Run Job worker), STORY-050 (`CandidaturaEnviada`), STORY-052 (`VagaEditadaMaterialmente`), STORY-047 (`VagaCancelada`).
- **Bloqueia:** STORY-054 (validação).
- **Pré-req:** Mailpit em homolog operante (já em pé pela STORY-021).

## Decisões já tomadas

- ADR-011: provedor de e-mail transacional + ACL.
- PDR-009: notificação obrigatória em edição material (com diff).
- STORY-014 (Anti-Corruption Layer) + STORY-021 (provedor implementado).

## Liberdade técnica

Decide: nome dos listeners, estrutura do worker, estratégia de fila (sugestão: usar `notificacoes.enviada_email_em IS NULL` como fila implícita; sem Redis/Beanstalkd no MVP); microcopy dos templates (PO revisa antes de aceitar). NÃO decide: lista de eventos consumidos (3 fixos), SLA de 60s, lista de templates (5 fixos).

## DoD

- [ ] CAs checados. *(CA-1..8, 10, 11 ok; faltam CA-9 SLA e CA-12 E2E — ambos exigem homolog.)*
- [ ] Cobertura + E2E verdes, SLA observado. *(Cobertura back/widget ok; E2E + SLA pendentes em homolog.)*
- [x] 5 templates ativos no editor (TemplateVersao ativa).
- [ ] Deploy de homolog: ciclo completo (candidata → e-mail no Mailpit do contratante).
- [x] `index.json` atualizado.
- [x] "Notas do agente" preenchida com link para os 5 templates carregados.

## Texto-seed v1 dos 5 templates (aprovado pelo PO — Alexandro, 2026-06-03)

> **Status:** **v1 aprovado pelo PO em chat (2026-06-03)** — destrava CA-6 e a estória inteira.
> Carregado pelo agente como `TemplateVersao` ativa (CA-6), mesmo padrão de STORY-015.
> Tom: sóbrio, direto, PT-BR, sem firulas — espelha o de STORY-021. Saudação padrão segue convenção do `TransacionalMail`: `"Olá, {nome}."` com fallback `"Olá."`. Assunto é canônico e fica fixado em `TipoEmail::assunto()` (ADR-011 §d) — **não reabrir** sem PDR. Variáveis usam `{snake_case}`; o renderer (STORY-020) faz a interpolação a partir do `payload jsonb` do registro de `notificacoes`.

### Convenções comuns

- **Remetente:** `no-reply@mail.turni.com.br` (config `mail.from`, ADR-011 §d).
- **Rodapé curto (todos):** `"Você recebeu este e-mail porque é parte do funil ativo de uma vaga no Turni. Dúvidas: contato@turni.com.br · Política de privacidade."`
- **In-app** (badge + painel lateral) reusa `h1` e a primeira linha do primeiro parágrafo como microcopy resumida; CTA in-app navega para `ctaUrl` interno (`/vaga/{vaga_id}` ou `/contratante/vagas/{vaga_id}/candidatos`).
- **Variáveis disponíveis em cada template:** documentadas no editor (CA-6) a partir do `payload` listado abaixo.

### 1. `candidatura_recebida_contratante` — disparado por `CandidaturaEnviada`

- **Destinatário:** contratante dono da vaga.
- **Payload (CA-2):** `{ profissional_nome, profissional_score, vaga_id, vaga_funcao, vaga_data_inicio, link_painel }`.
- **Assunto:** `Nova candidatura para sua vaga no Turni`
- **Preheader:** `{profissional_nome} se candidatou à sua vaga de {vaga_funcao}.`
- **H1:** `Nova candidatura recebida`
- **Saudação:** `Olá, {nome}.`
- **Parágrafos:**
  1. `{profissional_nome} se candidatou à sua vaga de {vaga_funcao} em {vaga_data_inicio}.`
  2. `Score de match: {profissional_score}/100. O painel mostra o detalhamento do score e os outros candidatos ranqueados.`
- **CTA:** label `Ver candidatos` · url `{link_painel}` (ex.: `https://app.turni.com.br/contratante/vagas/{vaga_id}/candidatos`)
- **Aviso:** `null`
- **Privacidade (CA-10):** sem CPF, sem telefone — só nome e score. Esses só entram no e-mail pós-aceite (EPIC-003).

---

### 2. `vaga_editada_material_profissional` — disparado por `VagaEditadaMaterialmente`

- **Destinatário:** profissional com candidatura pendente na vaga.
- **Payload (CA-3):** `{ vaga_id, vaga_funcao, diff: { campo: { antes, depois } }, prazo_em, link_detalhe }`. O `diff` traz **apenas** os campos materiais (PDR-009) — agente formata em lista "antes → depois" no e-mail.
- **Assunto:** `Vaga em que você se candidatou foi alterada — confirme até {prazo_em}`
- **Preheader:** `A vaga de {vaga_funcao} mudou. Confirme se ainda quer participar.`
- **H1:** `Uma vaga em que você se candidatou foi editada`
- **Saudação:** `Olá, {nome}.`
- **Parágrafos:**
  1. `O contratante alterou a vaga de {vaga_funcao} em que você se candidatou. Veja o que mudou:`
  2. *(bloco gerado pelo agente a partir de `diff` — uma linha por campo no formato `{campo_legivel}: {antes} → {depois}`. Ex.: "Início do turno: 03/06/2026 18:00 → 03/06/2026 20:00")*
  3. `Você tem até {prazo_em} para confirmar que ainda quer manter sua candidatura. Sem resposta, ela é retirada automaticamente.`
- **CTA:** label `Confirmar ou retirar` · url `{link_detalhe}` (ex.: `https://app.turni.com.br/vaga/{vaga_id}`)
- **Aviso:** `Sem resposta até {prazo_em}, sua candidatura é retirada automaticamente.`
- **Observação:** se o `diff` for grande (3+ campos), agente resume os 2 mais relevantes (data/hora, valor) e usa "+ outras alterações" — detalhe completo fica no detalhe da vaga.

---

### 3. `vaga_cancelada_profissional` — disparado por `VagaCancelada`

- **Destinatário:** profissional com candidatura pendente na vaga.
- **Payload (CA-4):** `{ vaga_id, vaga_funcao, vaga_data_inicio, link_feed }`.
- **Assunto:** `Vaga em que você se candidatou foi cancelada`
- **Preheader:** `O contratante cancelou a vaga de {vaga_funcao}.`
- **H1:** `Vaga cancelada pelo contratante`
- **Saudação:** `Olá, {nome}.`
- **Parágrafos:**
  1. `O contratante cancelou a vaga de {vaga_funcao} marcada para {vaga_data_inicio}. Sua candidatura foi retirada automaticamente.`
  2. `Você não precisa fazer nada. Veja outras vagas próximas no feed.`
- **CTA:** label `Ver outras vagas` · url `{link_feed}` (ex.: `https://app.turni.com.br/feed`)
- **Aviso:** `null`
- **Observação:** a UI já mostra um banner no card no momento do cancelamento; este e-mail garante a chegada quando o profissional está com o app fechado.

---

### 4. `vaga_editada_material_candidatura_mantida_contratante` — disparado quando profissional **confirma** após edição

- **Destinatário:** contratante dono da vaga.
- **Payload:** `{ profissional_nome, profissional_score, vaga_id, vaga_funcao, vaga_data_inicio, link_painel }`.
- **Assunto:** `Candidato confirmou continuar na sua vaga editada`
- **Preheader:** `{profissional_nome} confirmou continuar na sua vaga de {vaga_funcao}.`
- **H1:** `Candidato mantido após edição`
- **Saudação:** `Olá, {nome}.`
- **Parágrafos:**
  1. `{profissional_nome} viu as alterações que você fez na vaga de {vaga_funcao} ({vaga_data_inicio}) e confirmou que quer continuar candidatado.`
  2. `O score atualizado segue no painel.`
- **CTA:** label `Ver candidatos` · url `{link_painel}`
- **Aviso:** `null`

---

### 5. `vaga_editada_material_candidatura_retirada_contratante` — disparado quando candidatura é **retirada** após edição (voluntária ou auto)

- **Destinatário:** contratante dono da vaga.
- **Payload:** `{ profissional_nome, vaga_id, vaga_funcao, vaga_data_inicio, motivo: "voluntaria" | "auto_24h", link_painel }`.
- **Assunto:** `Candidato deixou sua vaga após a alteração`
- **Preheader:** `{profissional_nome} não confirmou as mudanças na vaga de {vaga_funcao}.`
- **H1:** `Candidato saiu da vaga após edição`
- **Saudação:** `Olá, {nome}.`
- **Parágrafos:**
  1. *(condicional por `motivo`)*
     - se `motivo == "voluntaria"`: `{profissional_nome} optou por não continuar candidatado à vaga de {vaga_funcao} ({vaga_data_inicio}) depois das alterações.`
     - se `motivo == "auto_24h"`: `{profissional_nome} não respondeu à alteração da vaga de {vaga_funcao} ({vaga_data_inicio}) no prazo de 24h. A candidatura foi retirada automaticamente.`
  2. `Outros candidatos seguem ativos no painel. Você pode editar a vaga novamente ou aguardar novas candidaturas.`
- **CTA:** label `Ver candidatos` · url `{link_painel}`
- **Aviso:** `null`

---

### Notas para o agente

- **Renderização do `diff` (template 2):** o `payload.diff` é um `jsonb` com chave por campo material. Campos materiais conhecidos (PDR-009): `data_inicio`, `data_fim`, `valor`, `funcao`, `endereco`. Mapeie nome técnico → rótulo legível PT-BR (`data_inicio` → "Início do turno", `valor` → "Valor", etc.). Formato de data/hora segue **IDR-026** (`TurniDateTime`) — sempre local na UI/e-mail, UTC no banco.
- **`prazo_em`:** já calculado no `payload` (STORY-052) como `min(criada_em + 24h, vaga.data_inicio)`. Renderize com `TurniDateTime` em PT-BR.
- **Paridade HTML/text/plain:** as duas vistas consomem o mesmo array de conteúdo (mesmo padrão de `TransacionalMail` da STORY-021).
- **Idempotência:** chave sugerida = `"{tipo}:{candidatura_id}:{vaga_versao}"` para edição material; `"{tipo}:{candidatura_id}"` para os demais.
- **Quando PO validar v1:** este bloco vai pro editor (`TemplateVersao` v1 ativa). Edições futuras passam pelo editor (STORY-020), gerando v2/v3 — não reescrever esta seção.

## Notas do agente

### Progresso (sessão 2026-06-03)
- **Design (CA-8 spec):** `SCREEN-STORY-053-notificacoes` criada + protótipo HTML, **aprovado por
  Alexandro** em chat (sino+badge no AppBar das duas homes; painel `endDrawer`; tema herda o papel;
  badge em `error`; microcopy reusa o texto-seed dos e-mails). `status: ready`.
- **CA-1..CA-4 (feito, verde):** migração `notificacoes` (enum nativo, fila implícita de e-mail
  `enviada_email_em IS NULL`, idempotência por `idempotency_key`), model+factory, 3 listeners
  (`HandleCandidaturaEnviada`/`HandleVagaEditadaMaterialmente`/`HandleVagaCancelada`) registrados
  síncronos no `AppServiceProvider` (consistência transacional), `CriarNotificacaoService` (audit
  `notificacao.criada`), `DiffParaTexto` + `DataHora` (pt-BR 24h). 6 testes (listeners 100%).
- **CA-7 (feito, verde):** `NotificacaoController` + rotas; `GET /api/notificacoes[?lidas=false]`
  (50 + `nao_lidas` p/ badge), `marcar-lida` (RBAC destinatario, 404 terceiros), `marcar-todas-lidas`.
  7 testes.
- **CA-8 (feito, verde):** UI Flutter — `NotificacoesSino` (badge `error` nas `actions:` de
  feed/minhas-vagas), `NotificacoesPainel` (`endDrawer`, tema por papel, estados
  lista/loading/vazio/erro), `NotificacoesController` (otimista) + serviço. Toque marca lida +
  navega por tipo. 14 testes; suíte WebApp 340 verde; analyze/format limpos.

### Progresso (sessão 2026-06-03 — CA-5/6, e-mail)
- **CA-6 (feito, verde — Path A):** coluna `categoria` em `templates` (migração nos **dois** apps,
  api + admin — memória `project-backoffice-db-ownership`); 5 corpos editáveis como `Template`
  categoria `email` + `TemplateVersao` v1 ativa, slug = `NotificacaoTipo::templateSlug()`
  (`<tipo>_email`). Conteúdo = **front-matter (`chave: valor`) + `---` + corpo Markdown** (formato
  escolhido pelo PO), vendorado em `database/seeders/emails/` (api e admin). Editor do Backoffice
  ficou **categoria-aware**: `TemplateContentValidator::placeholdersDesconhecidosPara($slug,...)`
  valida `{snake_case}` contra `EmailTemplateCatalogo` (variáveis por slug, documentadas no
  diálogo do editor); `TemplateRenderer::htmlEmail` faz chips; catálogo/detalhe rotulam a categoria.
- **CA-5 (feito, verde):** `EmailTemplateRenderer` (parse front-matter + interpola `{snake_case}`
  com o payload → array do layout de STORY-021; falta de variável = exceção, não envia incompleto),
  `NotificacaoMail` (reusa `emails.transacional*`), command `notificacoes:enviar-emails` (Schedule
  `everyMinute` em `routes/console.php`; sucesso→`enviada_email_em`, falha→`tentativas_envio++`,
  3ª→`falha_envio_em` + log ERROR `notificacao.email.falhou`). Assunto canônico de
  `NotificacaoTipo::assuntoEmail()` com `{prazo_em}` interpolado no envio.
- **Verificação manual (Mailpit local):** notificação `candidatura_recebida` pendente → worker →
  e-mail no Mailpit (de `no-reply@mail.turni.com.br`, assunto + corpo interpolados, "Olá, {nome}.")
  + `enviada_email_em` setado. ✓
- **Templates 4/5 (wiring — feito, verde):** `NotificarRevisaoAposEdicao` cria as notificações ao
  contratante nos hooks de `RevisarCandidaturaService::manter()` (template 4 `candidatura_mantida`)
  e `::retirar()` + `AutoRetirarAposEdicaoCommand` (template 5 `candidatura_retirada`, motivo
  `voluntaria`/`auto_24h`). Síncrono na transação da transição; `motivo_texto` pré-resolvido;
  idempotência `<tipo>:<candidatura_id>:<vaga.versao_atual>`. 4 testes (serviço 100%, RevisarCandidatura
  100%); STORY-052 (13 testes) segue verde.

### Decisões / Descobertas / Bloqueios / IDRs
- **IDR-053 (a registrar):** assuntos dos 5 e-mails de notificação ficam em `App\Enums\NotificacaoTipo`
  (api), **não** no `Turni\Domain\Email\TipoEmail` compartilhado — o `TipoEmail` é contrato com o
  `admin` (ADR-011 §d "não reabrir"), `match` exaustivo; a família de notificação é nova e fica na api.
- **Path A escolhido pelo PO (Alexandro):** os 5 **corpos** de e-mail moram no editor do Backoffice
  (STORY-020) como `TemplateVersao` ativa, interpolados com o `payload` — exige generalizar o sistema
  de templates (hoje só contratos) p/ categoria `email` + renderer de interpolação `{snake_case}`.
- **Templates 4/5 (mantida/retirada):** não há evento de domínio para "confirmar/retirar após
  edição" — serão criados via hook nos endpoints `confirmar-apos-edicao`/`retirar-apos-edicao`
  (STORY-052) e na auto-retirada (`auto_24h`). Fora dos 3 listeners da CA-2/3/4.

### Pendente (próxima sessão — só o que exige homolog)
- **CA-12 / CA-9:** E2E 3 cenários (Mailpit homolog, 0 flake em 3 runs) + SLA ≤60s p95 via log-based
  metric + deploy homolog (ciclo candidata→e-mail). Exigem ambiente; ficam para o fechamento da
  estória (junto com STORY-054, o validador do épico).

### Cobertura final
- Unitários back: listeners 6 + endpoints 7 + **renderer 6 (EmailTemplateRenderer 96% linhas)** +
  **worker (EnviarEmailsNotificacaoCommand 97% linhas) + NotificacaoMail 100% + seeder 92%**.
  Suíte `tests/{Feature,Unit}/Notificacao` = 26 verde. `pint --test` limpo (api).
- Admin: `EmailTemplateValidator` + seeder + editor de e-mail = 9 testes novos; suíte Templates 43
  verde. `pint --test` limpo (admin).
- Widget WebApp: 14 testes da feature notificações; suíte 340 verde. Falta E2E (CA-12).
- E2E/SLA: pendente (CA-12/CA-9 — Mailpit homolog).
### Templates carregados (CA-6)
- 5 `Template` categoria `email`, v1 ativa, slug `<tipo>_email`: `candidatura_recebida_email`,
  `vaga_editada_material_email`, `vaga_cancelada_email`,
  `vaga_editada_material_candidatura_mantida_email`, `vaga_editada_material_candidatura_retirada_email`.
  Seed: `apps/api/database/seeders/emails/*.md` (+ cópia no admin). Editáveis no Backoffice
  (`/templates`), com variáveis documentadas por `EmailTemplateCatalogo`.
### Links
- Commits: `9b00dba` (design+listeners), `248f9d6` (endpoints), `00c8ee7` (Flutter CA-8); CA-5/6
  nos commits desta sessão. PR/Deploy: pendente.
