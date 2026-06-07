---
story_id: STORY-075
slug: banner-global-homolog-pagamentos-simulados
title: Banner global em homolog — "Ambiente de teste — pagamentos simulados" (PDR-017)
epic_id: EPIC-003
sprint_id: SPRINT-2026-W28
type: implementation
target_role: programador
requires_design: false  # microcopy + cor de aviso do DS — reuso sem nova SCREEN
design_screen_id: null
status: in_review
owner_agent: claude-opus-4-8-programador
created_at: 2026-06-04
updated_at: 2026-06-07
estimated_session_size: S
produces_idr: null
renumbered_from: STORY-074  # colisão #2 — EPIC-011 (geolocalização, spin-off de STORY-057) reservou STORY-074 no mesmo dia para "geocoding endereço estabelecimento"; renumerada para STORY-075 (próximo livre)
---

# STORY-075 — Banner global em homolog "Ambiente de teste — pagamentos simulados"

## Contexto

PDR-017 decidiu que o MVP usa **fake genérico** atrás da ACL de pagamento; integração Pagar.me real entra na próxima wave. Em homolog, o ciclo do turno fim a fim mostra "Pix enviado" para o profissional e "Pagamento confirmado" para o contratante — mas nada cai de verdade. **Sem indicação visível, qualquer demonstração externa (Alexandro, equipe Turni, parceiros, investidores) pode tomar o comportamento como real e gerar expectativa equivocada.**

A decisão do PDR-017 (item "Comunicação ao usuário" da AskUserQuestion de 2026-06-04) é: **banner global persistente em homolog** com microcopy clara, **não aparece em produção**.

- Épico: `epics/EPIC-003-aceite-pin-e-pix/epic.md`
- Decisão: `decisions/pdr/PDR-017-pagamento-via-fake-generico-no-mvp.md`
- Documentos: DDR-001 (Design System), DDR-002 (locale pt-BR + 24h).

## O quê

Banner global no topo de **toda tela autenticada** do WebApp Flutter (`apps/webapp`) e do Backoffice Livewire (`apps/admin`) quando o ambiente for `homolog`. Mensagem: **"Ambiente de teste — pagamentos simulados"**. Cor de aviso do DDR-001 (DS), persistente (não dispensável), altura mínima que não atrapalhe a UX mas seja claramente visível.

Em produção (`live`) e em landing (`apps/landing`) o banner **não aparece**.

## Por quê

Elimina ambiguidade demonstrativa do MVP. Risco real: Alexandro abre homolog para parceiro/investidor, fluxo do turno corre fim a fim com "Pix enviado" visível, e o parceiro acha que o produto está rodando pagamentos reais. Trade-off de UX (perda de polimento estético do "produto pronto") é amplamente compensado pelo ganho de honestidade.

## Critérios de aceite

- [x] **CA-1:** Banner visível no topo de toda tela autenticada do WebApp quando `APP_ENV=homolog` (ou variável equivalente decidida pelo agente). Microcopy: "Ambiente de teste — pagamentos simulados". Espelhado no Backoffice.
- [x] **CA-2:** Banner **não aparece** em `APP_ENV=production` nem em `APP_ENV=local` (dev local) — só em `homolog`. Decisão: dev local não precisa do banner porque o desenvolvedor sabe o que está rodando; em produção, comportamento é real.
- [x] **CA-3:** Banner **não aparece** em `apps/landing` (não há fluxo de pagamento na landing — confusão impossível).
- [x] **CA-4:** Banner **não aparece** em telas pré-autenticação (login, cadastro, reset de senha) — não há ação financeira nessas telas e o banner polui a primeira impressão. Excepção: se o agente julgar valioso aparecer também antes do login para deixar claro a parceiros antes de se autenticarem, escalar ao PO antes de implementar.
- [x] **CA-5:** Banner não é dispensável (sem botão "fechar") — persistência é o ponto. Pode ser minimizado visualmente após scroll (decisão de UX do agente).
- [x] **CA-6:** Cor + tipografia consumem tokens do DS (DDR-001) — uso da cor de aviso/atenção. Não inventar cor nova.
- [x] **CA-7:** Acessibilidade — banner com `role="status"` ou equivalente; contraste AAA com o background; texto legível em telas pequenas (mobile-first).
- [x] **CA-8:** Cobertura ≥ 80% no código novo (widget Flutter + componente Livewire); teste cobre os 3 cenários de visibilidade (homolog mostra; production/local não mostra; landing/pre-auth não mostra).

## Fora de escopo

- Banner em produção — não aparece (PDR-017 só removeu Pagar.me; quando voltar na próxima wave, banner desaparece de homolog também e nunca aparece em produção).
- Mecanismo de feature flag externa (LaunchDarkly, etc) — usar env var simples; over-engineering desnecessário.
- Diferentes microcopias por papel (profissional vs contratante vs admin) — mesma microcopy para todos; simplicidade.
- Banner em e-mail transacional (STORY-067) — e-mails podem mencionar "ambiente de teste" no rodapé, mas isso é decisão da própria STORY-067 (e-mails em homolog já têm assinatura Mailpit que indica isso).

## Padrões de qualidade

≥ 80%. Tests unitários cobrem os 3 cenários. Sem regressão visual no auto-update da STORY-037 (PWA continua instalável; banner não quebra layout de instalação).

## Dependências

- **Bloqueada por:** nenhuma — ortogonal ao caminho crítico do EPIC-003. Pode iniciar a qualquer momento da W28.
- **Bloqueia:** STORY-068 (validador verifica banner visível como CA do checklist).
- **Pré-requisitos:** `APP_ENV` ou variável equivalente já configurada por ambiente (herdada de STORY-007).

## Decisões já tomadas

- **PDR-017** — Pagamento via fake genérico no MVP; comunicação ao usuário em homolog via banner global (decisão de produto fixada).
- DDR-001 — Design System (tokens de cor).
- DDR-002 — Locale pt-BR (microcopy em português).

## Liberdade técnica

Você decide: nome exato da variável de ambiente, posição CSS do banner, altura, comportamento em mobile (sticky vs absolute), microcopy exata se julgar que a sugestão pode ser mais clara — escalar ao PO se quiser desviar.

Você NÃO decide: que o banner aparece em homolog (PDR-017 fixa); que não aparece em produção (PDR-017 fixa); que é não-dispensável (PDR-017 fixa — persistência é o ponto).

## Definição de Pronto

- [ ] CAs marcados; deploy em homolog verificado por Alexandro (banner visível em WebApp + Backoffice; ausente em landing).
- [ ] Pipeline verde com cobertura exigida.
- [x] `index.json` atualizado.
- [x] "Notas do agente" preenchida.

## Protocolo

`docs/skills/po/references/agent-task-format.md`.

## Notas do agente

### Entrada inicial (2026-06-07 — antes de codar)

**Documentos lidos:** story inteira; PDR-017; DDR-001 (tokens.md §4 — semânticas); DDR-002; agent-task-format.md; código existente (webapp `main.dart`/`router.dart`/`ds/tokens.dart`/`core/app_update/widgets/update_banner.dart`; admin `components/layouts/admin.blade.php`; `release.yml`; `infra/envs/homolog/main.tf`).

**Entendimento consolidado:** faixa persistente "Ambiente de teste — pagamentos simulados" no topo de toda tela autenticada do WebApp e do Backoffice, exclusiva de homolog. Não-dispensável (PDR-017 fixa). Não aparece em production/local, landing, nem pré-auth.

**Spike de design (rabisco — papel Designer, sync antes do código):**

```
┌──────────────────────────────────────────────────────────┐
│ ⚠  Ambiente de teste — pagamentos simulados              │  ← faixa ~36px, full-width
├──────────────────────────────────────────────────────────┤
│ (AppBar / sidebar / conteúdo da tela — empurrado, não    │
│  coberto)                                                 │
└──────────────────────────────────────────────────────────┘
```

- **Tokens (DDR-001 §4, padrão preferido para feedback):** fundo `warning.soft` (`#FBEED1` claro / `rgba(212,169,92,.14)` escuro) + texto neutro alto-contraste (`text.strong`: `#0F1B2D` / `#ECEDE5` — ≈14:1, **AAA ✅** CA-7) + ícone na cor `warning` (`#9A6E25` / `#D4A95C`, ≥3:1 sobre o soft ✅). O sólido + branco daria só 4.5:1 (AA) — reprovaria o CA-7; o soft é também o padrão canônico do DS. Nenhuma cor nova (CA-6).
- **Anatomia:** ícone de atenção + texto 13px peso 500, centralizado, padding vertical 8px (alvo legível mobile ≥360px, texto único sem truncar). Sem botão fechar (CA-5).
- **Posição:** topo absoluto, **empurra** o conteúdo (Column, não Stack/overlay) — não cobre AppBar nem o UpdateBanner da STORY-037 (que é flutuante por cima, sem conflito de layout).
- **Decisão de UX (liberdade do CA-5):** sem minimização ao scroll — faixa fina integral sempre visível. Minimizar adicionaria estado/JS/scroll-listener sem ganho real numa faixa de 36px (KISS).
- **Identificadores estáveis:** `Key('env-banner')` (Flutter) e `data-testid="env-banner"` (Backoffice).
- **A11y:** `Semantics(label: 'Aviso: ...')` container no Flutter; `role="status"` no blade (CA-7).
- **CA-4 (exceção pré-login):** avaliada e NÃO exercida — banner só pós-auth, como o default da story. Sem escalonamento.

### Decisões tomadas

- **`TURNI_ENV` como variável de ambiente** (liberdade técnica da story) — **não** `APP_ENV`: descoberta abaixo mostra que `APP_ENV=homolog` no Laravel não é viável. WebApp: `--dart-define=TURNI_ENV=homolog|production` injetado pelo `release.yml` conforme a tag (rc → homolog); default `local` em build local (CA-2 de graça). Admin: env var `TURNI_ENV=homolog` no Terraform (`cloud_run_admin`), lida via `config('turni.env')`; ausente em prod/local → banner não renderiza.
- **WebApp — critério "tela autenticada" = sessão ativa** (`AuthService.isLoggedIn`, que é `ChangeNotifier`): cobre exatamente o conjunto pós-auth (incl. `/welcome` e `/completar-cadastro`) e exclui pré-auth (CA-4) sem lista de rotas duplicada do guard.
- **Backoffice — banner no layout `components/layouts/admin.blade.php`**: é o layout exclusivo das telas autenticadas; login/forgot-password usam markup próprio → CA-4 estrutural, sem condicional de rota.
- **Landing (CA-3):** nada a fazer — `apps/landing` não compartilha código com webapp/admin; teste de regressão não aplicável (sem ponto de injeção).

### Descobertas

- **Em homolog, API/Admin/jobs rodam com `APP_ENV=production`** (deliberado — otimizações do Laravel; `infra/envs/homolog/main.tf`). O pré-requisito da story ("APP_ENV herdada de STORY-007") **não distingue homolog de prod** no backend — daí a variável dedicada `TURNI_ENV`. Registrado para o validador (STORY-068).
- O artefato Flutter web é **buildado por tag** (rc e final geram builds distintos no `release.yml`), então injetar ambiente via `--dart-define` no build é seguro — um build rc nunca é promovido a prod.

### Plano (3–5 bullets)

1. WebApp TDD: testes vermelhos do `EnvBanner`/`EnvBannerHost` → widget com tokens warning → plug no `MaterialApp.builder`.
2. Admin TDD: testes Pest vermelhos (homolog/production/local/login) → parcial blade + `config/turni.php`.
3. Plumbing: `release.yml` (dart-define) + `infra/envs/homolog/main.tf` (env var admin).
4. E2E browser real local (cenário homolog visível + cenário local ausente) + suíte completa + lint (flutter analyze, dart format, pint api+admin).
5. Notas finais, index.json, commit/push, roteiro de teste.

### Mapeamento CA → testes planejados

| CA | Teste(s) |
|---|---|
| CA-1 (visível homolog autenticado, microcopy) | widget: `env_banner_test.dart` — `mostra banner em homolog com sessão ativa (microcopy exata)`; Pest: `EnvBannerTest` — `banner visível no dashboard quando turni.env=homolog` |
| CA-2 (ausente production/local) | widget: `não mostra em production` + `não mostra em local`; Pest: idem 2 cenários |
| CA-3 (landing) | N/A estrutural (sem ponto de injeção) — justificado nas Notas |
| CA-4 (ausente pré-auth) | widget: `não mostra sem sessão mesmo em homolog`; Pest: `login não exibe o banner mesmo em homolog` |
| CA-5 (não dispensável) | widget: `não há botão de fechar / banner não some após interação` |
| CA-6/CA-7 (tokens DS + a11y) | widget: `usa tokens warning do DS e expõe Semantics de status`; blade usa vars CSS do DS (asserção de classe + role="status" no Pest) |
| CA-8 (cobertura ≥80% + 3 cenários) | conjunto acima cobre os 3 cenários nos 2 apps; cobertura medida ao final |

Bordas/exceções planejadas: valor de ambiente inesperado (ex.: `TURNI_ENV=staging` → não mostra — fail-safe), sessão expira em tela aberta (banner some junto do redirect), tela estreita 360px (texto não overflowa).

### Mapeamento CA → teste (final)

| CA | Testes que provam |
|---|---|
| CA-1 | webapp `env_banner_test.dart`: "mostra o banner em homolog com sessão ativa, microcopy exata"; "mostra o banner também para contratante"; admin `EnvBannerTest.php`: "CA-1: banner visível no dashboard quando turni.env=homolog"; "CA-1: banner presente também nas demais telas autenticadas"; E2E `banner_visibility_test.dart`: "homolog: banner visível pós-login com a microcopy exata"; "homolog: banner persiste ao navegar entre telas autenticadas" |
| CA-2 | webapp: "NÃO mostra em production"; "NÃO mostra em local"; admin: "CA-2: production"; "CA-2: local"; E2E (gate normal, TURNI_ENV ausente): "local: logado e MESMO ASSIM sem banner" |
| CA-3 | N/A estrutural — `apps/landing` não compartilha código com webapp/admin; não há ponto de injeção do banner (justificado em "Decisões") |
| CA-4 | webapp: "NÃO mostra sem sessão (pré-auth) mesmo em homolog"; "banner aparece no login da sessão e some no logout"; admin: "CA-4: login (pré-auth) NÃO exibe o banner mesmo em homolog"; E2E: "pré-auth (/login) NUNCA mostra o banner" |
| CA-5 | webapp: "não tem botão de fechar nem qualquer ação interativa"; admin: "CA-5: banner não tem botão de fechar" |
| CA-6 | webapp: "tema claro: fundo warning.soft + texto neutro alto-contraste + ícone warning"; "tema escuro: tokens warning escuros"; admin: "CA-6: banner consome tokens do DS" |
| CA-7 | webapp: "expõe Semantics de status não-modal"; "legível em tela estreita 360px — sem overflow"; admin: asserção `role="status"` no teste CA-1. Contraste: warning.soft #FBEED1 × text.strong #0F1B2D ≈ 14:1 (**AAA**) nos dois temas |
| CA-8 | env_banner.dart **100%** de linhas (23/23); 13 widget tests + 9 Pest + 3 cenários E2E; os 3 cenários de visibilidade cobertos nos 2 apps |

Bordas/exceções cobertas: ambiente desconhecido (`staging`) e vazio/null → fail-safe não mostra (webapp + admin); sessão expira → banner some reativamente; 360px sem overflow.

### Bloqueios encontrados
- Nenhum.

### IDRs criados
- Nenhum — `TURNI_ENV` é decisão local desta story (documentada aqui, no config e no Terraform); não muda padrão transversal de código. Se outra story precisar de detecção de ambiente de negócio, promover a IDR.

### Cobertura final
- Unitários (webapp): `lib/core/env/env_banner.dart` — **100%** (23/23 linhas).
- Admin: 9 testes de feature cobrem o parcial blade + `config/turni.php` (config sem lógica; views não são instrumentáveis por linha — cobertas por asserções de HTML nos 5 cenários de visibilidade).
- Suíte completa local: webapp 548 passed; admin 127 passed; pint api (402 files) e admin (91 files) limpos; `flutter analyze --no-fatal-infos` limpo (2 infos pré-existentes em `pre_cadastro_*` — não tocados por esta story).
- E2E browser real (gate local IDR-004): `make e2e` completo **exit 0** — integration_test do WebApp (incl. env_banner em modo `local`, ausência assertada), `make e2e-webapp-banner` (build com `TURNI_ENV=homolog`: visível pós-login, persiste na navegação, ausente pré-auth — "All tests passed"), smoke Playwright e Backoffice. **2 flaky pré-existentes** no Playwright do admin (`fila-aprovacao.spec.ts` (a), `pix-falhas.spec.ts` (b)) — retry verde, não relacionados a esta story; o resíduo de teste em pix_falhas já está anotado para o validador (STORY-068).

### Links de evidência
- PR: n/a — workflow do projeto é commit direto na main (sem PR); evidências nos commits `8d9dd2c` (red webapp), `1ad478c` (green webapp), `3c4c0d9` (red admin), `ec81bcc` (green admin), `6f9e56c` (plumbing).
- Pipeline: v0.1.0-rc.84 verde — https://github.com/alcatechgroup/mvpturni-mvp/actions/runs/27092409291 (build com `--dart-define=TURNI_ENV=homolog`; smoke pós-deploy ok; `version.json`=rc.84; microcopy + `env-banner` confirmados no `main.dart.js` servido).
- Terraform aplicado em homolog (2026-06-07): `TURNI_ENV=homolog` na revisão ativa do `turni-admin-homolog` (00094-g89, 100% tráfego, mesma imagem rc.83→84); plan pós-apply sem drift.
- Deploy de homologação (screenshot do banner): aguardando verificação visual do Alexandro (WebApp + Backoffice pós-login; ausente em landing e pré-auth).
