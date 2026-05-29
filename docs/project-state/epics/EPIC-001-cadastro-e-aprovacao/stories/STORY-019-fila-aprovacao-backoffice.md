---
story_id: STORY-019
slug: fila-aprovacao-backoffice
title: Fila de aprovação no Backoffice (visão + aprovar + remover)
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: implementation
target_role: programador
requires_design: true
design_screen_id: SCREEN-STORY-019-fila-aprovacao
status: done
owner_agent: programador+designer (claude-opus-4-8)
created_at: 2026-05-28
updated_at: 2026-05-29
estimated_session_size: M
---

# STORY-019 — Fila de aprovação no Backoffice

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

Esta estória entrega a **primeira ferramenta operacional real** do backoffice mínimo viável (PDR-003): a fila de cadastros pendentes que a equipe Turni precisa para honrar o SLA público de 24h declarado em `non-functional.md`. Sem ela, profissional e contratante pré-cadastrados em STORY-017/018 nunca saem do estado `pendente_aprovacao` — todo o fluxo do EPIC-001 trava.

A fila respeita o desenho mínimo de PDR-001 e do `epic.md`: **aprovar é 1 clique**; **recusar = remover o usuário** (não há flag de "recusado" no MVP — `epic.md` §Fora de escopo). O admin escolhe entre **aprovar** (dispara transição `pendente_aprovacao → liberado(welcome=false, cad=false)` + e-mail de aprovação concedida via STORY-021) e **remover** (delete físico ou soft-delete — segue ADR-009; sem motivo registrado no MVP por PDR-001). Toda ação é registrada em **audit log de admin** (ADR-009).

A fila precisa diferenciar visualmente **profissional** (com `tipo_pessoa` PF/MEI/PJ visível) de **contratante**, com filtro por papel. Apresenta os campos pré-aprovação coletados nas STORY-017/018, incluindo a foto, para que o admin possa fazer julgamento humano básico.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de codificar:
  - `docs/especificacao/domain/usuario.md` §"Estados do usuário" e §"Atributos por papel"
  - `docs/project-state/decisions/pdr/PDR-001-tipos-de-pessoa-aceitos.md` (3 tipos para profissional; recusa = remoção)
  - `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` (backoffice mínimo viável)
  - `docs/project-state/decisions/adr/ADR-007-auth-base-e-roteamento.md` §e (audit log de admin)
  - `docs/project-state/decisions/adr/ADR-009-modelo-de-dados-identidade-epic-001.md` (transição de estado; ownership; audit log)
  - `docs/especificacao/non-functional.md` §"Análise de cadastro em até 24h"
  - `docs/project-state/design/screens/SCREEN-STORY-019-fila-aprovacao.md` (Designer entrega antes)
  - `docs/project-state/design/system/preview-backoffice.html`, `tokens.md` — tema admin do DDR-001
  - `docs/skills/programador/SKILL.md`, `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Entregar fila de aprovação no Backoffice Livewire, acessível apenas ao admin autenticado (via STORY-016):

1. Rota `/aprovacoes` no admin (acessível pelo menu de navegação principal — ainda mínimo). Apenas para `role=admin`; não-admin recebe 403 fail-secure (já garantido por STORY-016).
2. **Lista** dos usuários em `status = pendente_aprovacao`, ordenada por `created_at` ascendente (FIFO — quem chegou primeiro aparece primeiro). Paginação ou rolagem virtual conforme volume esperado (MVP: ≤ 100 pendentes simultâneos — paginação simples é OK).
3. **Filtro** por papel (`todos` | `profissional` | `contratante`) e, para profissional, sub-filtro por `tipo_pessoa` (PF/MEI/PJ). Filtro persiste em querystring para o admin compartilhar URL.
4. **Visão de item da lista**: card com foto, nome, e-mail, telefone, cidade, papel, tipo de pessoa (quando profissional), tempo desde o cadastro (relativo: "há 3h", "ontem"), CTA primário "Ver detalhes".
5. **Detalhe do usuário** (drawer/modal ou rota dedicada — sua decisão técnica): exibe **todos os campos** coletados no pré-cadastro (STORY-017 ou STORY-018 conforme o caso), foto em tamanho maior, timestamp do aceite dos Termos, indicador visual do **template contratual aplicável** (`pf_autonomo_eventual` para PF; `mei_pj_b2b` para MEI/PJ e para contratante) com link/preview do template **ativo no momento** — apenas leitura aqui; o editor é STORY-020.
6. **Ação "Aprovar"** com botão primário visível e confirmação (clique → dialog "Confirma a aprovação?" → confirma):
   - Transição `pendente_aprovacao → liberado(welcome_visto=false, cadastro_completo=false)`.
   - Grava evento `admin.user.approved` no audit log (ADR-009) com `actor_user_id` do admin, `target_user_id`, `target_role`, `target_tipo_pessoa` (quando aplicável), timestamp, IP, user-agent.
   - Dispara e-mail `aprovacao_concedida` via ACL de STORY-014 (consumido por STORY-021; nesta estória, o **dispatch** existe — o conteúdo do e-mail vem de STORY-021).
   - **NÃO gera o AceiteEletronico aqui** — o aceite é registrado no fim do completar cadastro (STORY-023/024), quando o usuário tem todos os dados e clica explicitamente em "Aceito e concluir cadastro". Este é o **momento de consentimento legalmente relevante** — a aprovação do admin é o gate, não o ato de aceite. (Resolução da ambiguidade do `epic.md` registrada em PDR — ver §Decisões já tomadas.)
   - Toast/feedback "Cadastro aprovado. E-mail enviado a [email mascarado]." Após confirmação, o item sai da fila e a lista atualiza.
7. **Ação "Remover"** (recusa implícita por PDR-001): botão secundário com confirmação dupla ("Confirma a remoção? Esta ação não pode ser desfeita."):
   - Remove o usuário conforme estratégia de ADR-009 (delete físico vs soft-delete — siga o ADR; recomendação anterior do PDR-001 favorece exclusão sem histórico).
   - Grava evento `admin.user.removed` no audit log com `target_user_id`, `target_role`, timestamp, IP, user-agent. **Sem motivo textual** (PDR-001 — MVP).
   - Toast "Cadastro removido." Item sai da fila.
8. **Contador agregado** no topo da fila: "X pendentes (Y profissionais — A PF / B MEI / C PJ; Z contratantes)". Útil para a equipe Turni medir backlog.
9. **Indicador de SLA** por item: linha "há Xh" colorida em verde (≤ 12h), amarelo (12–20h), vermelho (> 20h, perto do SLA) — sinaliza visualmente o que precisa de atenção. Tema dual respeitado.

## Por quê (valor para o usuário)

Direto: equipe Turni (admin) consegue fazer o trabalho operacional central da WAVE-2026-01 sem depender do dev. Profissionais e contratantes pré-cadastrados saem de `pendente_aprovacao` e podem completar o ciclo. **SLA de 24h vira observável.** Indireto: primeiro evento real no audit log de admin (validando o desenho de ADR-009 em uso); destrava STORY-021 (e-mail de aprovação concedida); destrava STORY-022/023/024 (funil pós-aprovação).

## Critérios de aceite

- [ ] **CA-1:** Rota `/aprovacoes` no Backoffice em homolog responde 200 para admin autenticado; 403 fail-secure para qualquer outro papel ou não-autenticado.
- [ ] **CA-2:** Lista renderiza todos os usuários em `status = pendente_aprovacao` em FIFO; paginação funciona quando há > 20 itens (sugestão de page size, ajustável).
- [ ] **CA-3:** Filtros (papel, tipo de pessoa) funcionam, persistem em querystring, e o contador agregado reflete o filtro ativo.
- [ ] **CA-4:** Detalhe do usuário exibe **todos** os campos coletados no pré-cadastro do papel correspondente, foto em tamanho legível, timestamp do aceite, indicação do template contratual aplicável com **versão ativa** referenciada.
- [ ] **CA-5:** Botão "Aprovar" exige confirmação (dialog), executa transição de estado, grava audit log `admin.user.approved`, dispara e-mail (CA-7), exibe toast, atualiza lista.
- [ ] **CA-6:** Tentativa de aprovar usuário que **não está em `pendente_aprovacao`** (race condition: outro admin já aprovou em outra aba) retorna erro claro "Este cadastro já foi processado por outro admin" e atualiza a lista. Fail-secure.
- [ ] **CA-7:** Dispatch de e-mail `aprovacao_concedida` enfileira via fila `database` (ADR-002) usando ACL de ADR-011 (STORY-014). Em homolog: o e-mail é entregue ao inbox visual de teste (mailpit/Mailtrap conforme ADR-011) ou ao provedor real conforme a fase. **Conteúdo final do e-mail vem de STORY-021** — nesta estória basta o dispatch acontecer e o log estruturado registrar.
- [ ] **CA-8:** Botão "Remover" exige confirmação dupla, executa remoção (conforme ADR-009), grava audit log `admin.user.removed`, exibe toast, atualiza lista. Não envia e-mail ao removido (PDR-001 — MVP).
- [ ] **CA-9:** Audit log: todas as entradas escritas por esta estória são **imutáveis** (tentativa de UPDATE/DELETE em psql falha — verificação manual no runbook).
- [ ] **CA-10:** Indicador visual de SLA (verde/amarelo/vermelho) renderiza corretamente conforme tempo decorrido; cobertura WCAG AA nos dois temas (PDR-013): contraste suficiente; informação **não depende apenas de cor** (usa ícone + texto também).
- [ ] **CA-11:** Acessibilidade WCAG 2.1 AA: navegação por teclado em lista e dialogs; rótulos acessíveis; leitor de tela anuncia mudanças de lista após aprovar/remover.
- [ ] **CA-12:** Cobertura unitária ≥ 80% no código novo / ≥ 98% no núcleo (transição de estado, gravação no audit log, dispatch de e-mail, race condition de aprovação simultânea).
- [ ] **CA-13:** **E2E em browser real** cobrindo: (a) admin lista pendentes e filtra por profissional MEI; (b) admin aprova um profissional → item sai da fila + e-mail enfileirado no inbox de teste; (c) admin tenta aprovar mesmo cadastro 2× em abas distintas → segunda tentativa erra com mensagem clara; (d) admin remove um cadastro com confirmação dupla.
- [ ] **CA-14:** Log estruturado (ADR-008) com `request_id` para cada ação do admin nesta tela (aprovar/remover).

## Fora de escopo

- Recusa **explícita** com motivo registrado — PDR-001 declara fora do MVP. Remover = recusar implícito.
- Histórico de cadastros removidos — fora do MVP.
- E-mail ao removido — fora do MVP.
- Notificação push/Slack ao admin quando novo cadastro chega — fora do MVP.
- Reaprovação ou desfazer remoção — fora do MVP (admin terá que pedir o usuário se cadastrar de novo).
- Conteúdo final do e-mail de aprovação concedida — STORY-021.
- Geração de AceiteEletronico — STORY-023/024 (no fim do completar cadastro).
- Edição de templates — STORY-020.
- Dashboard de métricas (volume, tempo médio de aprovação) — fora do MVP do EPIC-001; entrega futura.

## Padrões de qualidade exigidos

`quality-standards.md`. Em particular:

- **Cobertura ≥ 80% / ≥ 98% núcleo** (transição de estado, audit log writer, dispatch de e-mail, idempotência/race conditions).
- **E2E em browser real** cobrindo CA-13 na pipeline de homolog (Backoffice via URL do Cloud Run conforme IDR-003).
- **TDD** nas regras.
- **Segurança (§4)**: toda ação na fila exige admin autenticado + middleware `role=admin`; CSRF nativo do Livewire; auditoria gravada em tabela append-only; nenhum dado sensível em log claro (e-mail mascarado).
- **LGPD**: removerd o usuário, dado é apagado conforme estratégia de ADR-009 (delete físico cumpre direito ao esquecimento manual mencionado em `non-functional.md`).
- **Observabilidade (§3)**: log estruturado por ação; métrica RED de aprovações por hora via log-based metric do Cloud Monitoring (cruzar com ADR-008); alerta quando há cadastro pendente há > 20h (sinaliza risco de SLA).
- **Acessibilidade (§5)**: WCAG 2.1 AA + tema dual.

## Dependências

- **Bloqueada por:** STORY-012 (ADR-009 — transições, audit log), STORY-013 (ADR-010 — referência ao template ativo no detalhe; pode ser placeholder se ADR-010 não fechou ainda, mas precisa estar pronta para CA-4 completo). STORY-014 (ADR-011 — dispatch via ACL). STORY-016 (auth + admin login funcionando + audit log writer). STORY-017 e STORY-018 (precisa ter cadastros em `pendente_aprovacao` para validar). STORY-015 (texto-seed dos templates, para CA-4 mostrar o template ativo). Designer entrega `SCREEN-STORY-019-fila-aprovacao` em `ready`; sync ≤15 min.
- **Bloqueia:** STORY-021 (consumo do dispatch para entregar conteúdo final do e-mail), STORY-022 (welcome só ativa quando admin aprovou), STORY-023/024 (completar cadastro só ativa quando admin aprovou + welcome visto), STORY-025 (validação).
- **Pré-requisitos:** STORY-006, STORY-007, STORY-016.

## Decisões já tomadas (não as reabra)

- **PDR-001** — Recusa = remoção sem motivo registrado.
- **PDR-003** — Backoffice mínimo viável; fila de aprovação faz parte do mínimo.
- **ADR-007 / ADR-009 / ADR-011** — auth admin; audit log; ACL de e-mail.
- **`epic.md`** explicitamente lista "Admin aprova com 1 clique; usuário recebe e-mail de notificação".
- **Decisão PO do EPIC-001 sobre momento do AceiteEletronico**: o aceite é gerado **no fim do completar cadastro** (clique explícito do usuário), **não na aprovação do admin**. Isso resolve uma ambiguidade do `epic.md` original ("anexado ao usuário no momento da aprovação") — naquela versão, faltavam dados (documento) no momento da aprovação. A interpretação consistente com `domain/usuario.md` (dado sensível só pós-aprovação) e com PDR-012 (versionamento e prova) é: **gate do admin** ≠ **momento do consentimento informado do usuário**. Decisão aplicada a partir do EPIC-001; vira PDR se necessário.
- **`non-functional.md`** — SLA 24h.

## Liberdade técnica do agente

Você decide:
- Componentes Livewire concretos (LiveList, LiveItem, LiveDialog, etc.).
- Paginação simples vs scroll infinito.
- Localização do botão de aprovação (na lista direta para 1-click? ou só dentro do detalhe? — recomendação PO: aprovação **só no detalhe**, para forçar o admin a ver os dados antes; configurar 1-clique direto na lista é otimização futura que vira pedido da equipe Turni se vier).
- Como exibir indicador de SLA (cor + ícone + texto).
- Estratégia de race condition (lock otimista com `updated_at` ou pessimista com `SELECT FOR UPDATE` — sua decisão, justificada).

Você NÃO decide:
- Gerar AceiteEletronico aqui (vai em STORY-023/024).
- Adicionar campo de motivo na remoção (PDR-001).
- Reabrir ADR-009 (transições).
- Suprimir audit log, cobertura, E2E, ou acessibilidade.

## Definição de Pronto (DoD)

- [ ] CA-1 a CA-14 passam com evidência.
- [ ] Cobertura medida no PR.
- [ ] E2E verde na pipeline de homolog (Backoffice).
- [ ] Audit log imutabilidade verificada (CA-9 evidência no runbook).
- [ ] Sync Designer↔Programador registrado.
- [ ] `index.json` atualizado.
- [ ] "Notas" preenchida.
- [ ] IDR se houve decisão técnica relevante.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/references/agent-task-format.md`. Carregue `docs/skills/programador/SKILL.md`. Confirme screen spec em `ready`. TDD nas regras. PR com evidência. `done` após deploy verde.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial (2026-05-29)
Documentos lidos: estória inteira; ADR-009 (transições, audit log, lista canônica de eventos, soft-delete=`recusado`); ADR-011 (ACL `EnviaEmailTransacional`/`EmailTransacional`/`TipoEmail`, fila `database`); `tokens.md` (perfil admin navy) + `preview-backoffice.html` (já mockava a "Fila de análise"); código do app admin (User, AdminAuditLog, AuditLogService, AdminOnly, RequestLogMiddleware, rotas, login/dashboard blade) e da API (migrações de pré-cadastro 017/018, modelos ProfissionalProfile/ContratanteProfile/Funcao).

Entendimento consolidado: a fila lê `users` pendentes (FIFO) + perfis; admin aprova (→`liberado` + audit `admin.user.approved` + dispatch e-mail) ou remove (→`recusado` + audit `admin.user.removed`, sem e-mail). Backoffice é Livewire/Blade desktop-first (PDR-003), não Flutter. STORY-013/014 foram **spikes** (sem código de Template/ACL) → CA-4 usa placeholder de template; CA-7 cria o **seam** da ACL com adapter log-only (entrega real é STORY-021).

### Sync Designer↔Programador (2026-05-29, mesma sessão)
Pontos alinhados antes de cristalizar a tela:
- **Plataforma:** Backoffice é Livewire/Blade desktop-first — spec descreve componentes Blade e usa `data-testid` (não `Key()` Flutter). Registrado na nota de plataforma do spec.
- **Detalhe:** drawer lateral (overlay, sem troca de rota) — mais simples em Livewire e preserva o contexto da fila. Aprovação **só no detalhe** (recomendação PO).
- **Remoção:** soft-delete via `status='recusado'` (ADR-009), não hard delete. Spec §10 e IDR-013.
- **Template aplicável (CA-4):** placeholder de leitura (link para texto-seed) — `TemplateVersao` é STORY-020. Aceito pela estória.
- **E-mail (CA-7):** dispatch via seam de ACL + adapter log-only; entrega real (Mailpit/Resend) é STORY-021 — o spec não promete inbox visual nesta estória.
- **Microcopy:** "Remover" (não "Recusar" do preview) — alinhado à estória/PDR-001.

### Decisões tomadas
- Soft-delete por `status='recusado'`; lock otimista por UPDATE condicional; seam da ACL de e-mail no admin com adapter log-only + job na fila `database`; paridade de migração byte-idêntica entre API e admin. Detalhe e justificativa em **IDR-013**.

### Descobertas
- API e Backoffice compartilham o banco `turni`; convenção de migrações byte-idênticas deduplicadas pelo runner.
- `preview-backoffice.html` já continha o mock da fila (DDR-001) — reusado como base do spec/layout.

### Bloqueios encontrados
- **Login do admin contra dados semeados quebrava (500 "password does not use the Bcrypt algorithm").** Causa: `apps/admin/.env` sem `HASH_DRIVER=argon2id` (ADR-007) → admin checava bcrypt enquanto a API gravava Argon2id. Corrigido (`.env`+`.env.example`). É **gap latente de STORY-016/Foundation** — sinalizar ao PO (ver Pendências). Desbloqueou a verificação em browser e o E2E.
- **CA-1 — menu de navegação ausente no ponto de entrada (pego em teste manual do Alexandro).** O dashboard `/` era a página standalone da STORY-016, **sem a sidebar** — a fila só era acessível digitando a URL. Meu E2E inicial entrava com `goto('/aprovacoes')`, mascarando o problema (testei a tela e as ações, não o caminho login→dashboard→menu). Corrigido: dashboard passou a usar o layout `components.layouts.admin` (sidebar global com "Visão geral" + "Cadastros pendentes"); E2E `loginAndOpenQueue` agora **navega pelo menu** (`data-testid=nav-aprovacoes`), e `NavegacaoTest` cobre o link no dashboard. **Lição:** E2E deve exercitar o ponto de entrada real, não dar `goto()` direto na tela sob teste.

### IDRs criados
- **IDR-013** — seam da ACL de e-mail, soft-delete por status, lock otimista, paridade de migração (+ a descoberta do HASH_DRIVER).

### Cobertura final
- `vendor/bin/pest --coverage`: **Total 92.4%** (≥80 ✓). Núcleo **`ApprovalService` 98.4%** (≥98 ✓). ACL de e-mail (VO/interface/adapter/job/enum) **100%**. 55 testes Pest passando (116 asserções); suíte admin inteira verde.

### Resultado final / evidência
- **CA-1** ✓ rota `/aprovacoes` 200 admin / 302→login não-auth / 403 não-admin (Pest).
- **CA-2** ✓ lista FIFO de pendentes + paginação 20 (Pest + tela).
- **CA-3** ✓ filtros papel/tipo_pessoa em querystring (`#[Url]`) + contador agregado (Pest + E2E).
- **CA-4** ✓ detalhe com todos os campos do pré-cadastro, foto, timestamp dos termos, template aplicável (placeholder de leitura) — screenshot do drawer.
- **CA-5** ✓ Aprovar com confirmação → transição + audit `admin.user.approved` + dispatch + toast + lista atualiza (Pest + E2E).
- **CA-6** ✓ aprovar cadastro já processado → "Este cadastro já foi processado por outro admin." sem efeito colateral (Pest + E2E 2 abas).
- **CA-7** ✓ dispatch `aprovacao_concedida` na fila `database` via ACL; log estruturado registra (Pest + IDR-013). Conteúdo/entrega = STORY-021.
- **CA-8** ✓ Remover com confirmação dupla → `recusado` + audit `admin.user.removed` (previous_status) + toast; sem e-mail (Pest + E2E).
- **CA-9** ✓ audit log imutável — UPDATE lança QueryException (Pest). REVOKE + trigger de STORY-016.
- **CA-10** ✓ SLA verde/amarelo/vermelho com **ícone (forma) + cor + texto** (não só cor); tokens AA dual-theme — screenshot.
- **CA-11** ✓ teclado (Esc fecha drawer/diálogo), `role=dialog/alertdialog`, `aria-live` na lista e toast, labels acessíveis.
- **CA-12** ✓ cobertura acima.
- **CA-13** ✓ E2E Playwright (a–d) **verde** em browser real (localhost:8002): `apps/admin/tests/e2e/fila-aprovacao.spec.ts`.
- **CA-14** ✓ log estruturado por ação (`admin.user.approved`/`removed`) com `request_id`.

### Aprovação do PO
- **Aprovada por Alexandro em chat em 2026-05-29**, após teste local da tela real no Backoffice (`localhost:8002/aprovacoes`) — incluindo o ajuste do menu de navegação (CA-1) pego no teste manual e a verificação de como o e-mail é despachado (job na fila `database` + log `email.transacional.dispatched`; entrega visual fica para STORY-021). Protótipo do Designer validado na mesma rodada. `status: done`.

### Pendências carregadas (não-bloqueantes para o aceite; operacionais/futuras)
- **Deploy em homolog + E2E na pipeline** (tag rc.N) — item operacional do fluxo de release; segue o padrão das STORY-017/018. Não executado nesta sessão.
- **STORY-021** consome o dispatch (entrega real do e-mail + conteúdo + Mailpit/Resend) — trocar binding do adapter log-only.
- **STORY-020** publica `TemplateVersao` ativo → substituir placeholder do CA-4 pela referência real.
- **Gap de Foundation sinalizado ao PO**: `HASH_DRIVER=argon2id` ausente no admin (corrigido aqui) era defeito latente de STORY-016 — login do admin contra seeds compartilhados não estava coberto por E2E executado de fato. PO decide se registra como F-NB.

### Links de evidência
- Spec + protótipo: `docs/project-state/design/screens/SCREEN-STORY-019-fila-aprovacao.md` (+ `STORY-019-fila-aprovacao/index.html`).
- Código: `apps/admin/app/{Livewire/FilaAprovacao.php, Services/ApprovalService.php, Domain/Email/*, Jobs/EnviarEmailTransacionalJob.php, Exceptions/CadastroJaProcessadoException.php, Models/*}`, `resources/views/{components/layouts/admin.blade.php, livewire/fila-aprovacao.blade.php}`, rota em `routes/web.php`.
- Testes: `apps/admin/tests/Feature/Aprovacoes/*`, `tests/Unit/EmailAclTest.php`, `tests/e2e/fila-aprovacao.spec.ts`; seed `apps/api/database/seeders/FilaAprovacaoPendentesSeeder.php`.
- IDR-013.
