---
idr_id: IDR-017
slug: auto-atualizacao-webapp-polling-skipwaiting-banner
title: Auto-atualização do WebApp Flutter — polling do version.json + SKIP_WAITING + banner
status: accepted  # proposed | accepted | superseded
decided_at: 2026-05-30
decided_by: programador
approved_by: Alexandro
owner_agent: programador-claude
related_story: STORY-037
related_adrs: [ADR-001, ADR-007]
related_idrs: [IDR-002]
supersedes: null
superseded_by: null
created_at: 2026-05-30
updated_at: 2026-05-31
---

# IDR-017 — Auto-atualização do WebApp: polling + SKIP_WAITING + banner

> **O que é um IDR.** Registra a decisão de implementação **local** que outros agentes
> precisam conhecer. Aqui, fixa os parâmetros operacionais da auto-atualização do WebApp
> que a ADR-001 deixou em aberto ("detalhe fino pode virar um ADR Frontend/PWA dedicado;
> a diretriz fica registrada aqui").

## Contexto

A ADR-001 §"Plano de verificação — Auto-atualização do WebApp" (linhas 130-133), aprovada
pelo PO em 2026-05-27, decidiu **o quê**: `index.html` e service worker com `no-cache`;
`version.json` publicado no deploy; o app compara a versão rodando com a do servidor ao
abrir e ao voltar de background; havendo nova, exibe aviso não-bloqueante que dispara
`skipWaiting` + reload; e um gate de versão mínima (`426`) nos fluxos críticos. A própria
ADR registrou que o **detalhe fino** (janela de polling, cache-buster, política de
dispensa, comportamento em dev) ficaria para um IDR — ou, quando o `426` entrar, para um
ADR Frontend/PWA dedicado.

A infra de servidor já existe (IDR-002 + STORY-007/008): `/version.json` com
`{"version":"vX.Y.Z-rc.N"}` e `Cache-Control: no-cache`; `--dart-define=APP_VERSION`
disponível no build; service worker padrão do Flutter plugado. STORY-037 implementa o
**lado cliente** e este IDR fixa os parâmetros operacionais dessa implementação.

## Decisão

> **Decidi implementar a auto-atualização do WebApp com polling de 5 min do `version.json`
> (com triggers extras), cache-buster `?t=<epochMs>` além do header `no-cache`, banner
> não-bloqueante cujo "Depois" não persiste, checagem desabilitada em `dev`, e o gate
> `426 Upgrade Required` deixado fora desta entrega.**

As cinco decisões operacionais:

1. **Janela de polling = 5 min** (`Timer.periodic`), além de uma checagem imediata em
   três triggers: (i) bootstrap do app, (ii) retorno da aba ao foreground
   (`document.visibilityState === 'visible'`), (iii) sucesso de login (hook explícito).
   O timer só corre enquanto a aba está visível (cancelado em `hidden`).
2. **Cache-buster `?t=<epochMs>`** anexado ao GET de `/version.json`, somado ao header
   `Cache-Control: no-cache` da própria request.
3. **"Depois" não persiste.** Fechar o banner só o esconde no ciclo atual; a próxima
   checagem que ainda veja versão nova reabre o banner. Não há "ignorar para sempre"
   (nem em `localStorage`, nem além do ciclo de polling).
4. **`dev` desabilita a checagem.** Quando `currentVersion == 'dev'` (build local sem
   `--dart-define=APP_VERSION`), o controller não faz polling nem mostra banner.
5. **Gate de versão mínima (`426 Upgrade Required`) fica FORA desta entrega.** Entra com
   os fluxos críticos (PIN/pagamento) no EPIC-003 e, junto dele, o conjunto sobe para um
   ADR Frontend/PWA dedicado.

## Por quê

- **5 min** balanceia frescor de release (uma release típica fica visível em < 5 min) vs.
  ruído de requests: ~288 GETs/dia/usuário de um payload de ~30 bytes, `no-cache` mas
  leve. Os triggers de `visibilitychange` + login cobrem o caso mais comum em mobile
  (usuário volta ao app depois de minutos/horas) sem esperar o tick do timer.
- **Cache-buster** porque alguns proxies/CDNs colapsam GETs idênticos mesmo com
  `no-cache`; `?t=<epochMs>` garante uma URL nova a cada checagem (defensivo, custo zero).
- **"Depois" não persistir** é coerência direta com a ADR-001 ("atualizar para a última
  publicada"). Persistir "ignorar versão X" abriria uma janela de versão indefinidamente
  velha — exatamente o problema que a estória paga.
- **`dev` desabilitar** evita ruído no desenvolvimento local (onde não há `version.json`
  de release coerente e a versão rodando é `dev`).
- **`426` fora** porque depende de fluxos que ainda não existem (PIN/pagamento) e a ADR-001
  já o vinculou a "fluxos críticos". Implementá-lo agora seria especulativo.

## Alternativas consideradas

- **Badge silencioso no rodapé (versão clicável → atualizar) em vez de banner** — descartado
  por ora: a ADR-001 pediu "aviso não-bloqueante" explícito; o badge fica como **sinal de
  revisão** se o banner for percebido como intrusivo em homolog (ver "Como verificar").
- **WebSocket/push para anunciar nova versão** — descartado: complexidade desproporcional
  para um MVP cujo deploy é por tag manual; o polling leve resolve com infra zero.
- **Trocar o service worker padrão do Flutter por Workbox/custom** — fora de escopo
  (STORY-008 CA-12 fixou o SW padrão como suficiente). Apenas comunicamos `SKIP_WAITING`
  com ele.

## Consequências

### Para outros agentes
- O módulo `lib/core/app_update/` é a fonte única de auto-atualização do WebApp. Não criar
  outro mecanismo de checagem de versão; reusar `AppVersionService`/`AppUpdateController`.
- O interop web (`ServiceWorkerBridge`, `VisibilityWatcher`) usa **conditional import**
  (`dart.library.js_interop`) com stub no-op para a VM — esse é o padrão a seguir para
  qualquer código que toque `package:web`/`dart:js_interop` neste app, para manter os
  testes unitários rodando em VM.
- A label de versão visível usa o widget reutilizável `AppVersionLabel`
  (`lib/ds/components/`). Quando o menu real da área logada chegar, mover a instância do
  `app_shell_screen` para o rodapé do menu — sem reescrever nada.
- O gate `426` é dívida conhecida (EPIC-003). Quem implementar PIN/pagamento reabre o tema
  e promove o conjunto a ADR Frontend/PWA.

### Para o projeto
- Nenhuma dependência transversal nova. Usa `package:http` (já presente) e
  `package:web`/`dart:js_interop` (já vêm com o Flutter SDK; `web` declarado no pubspec
  para satisfazer `depend_on_referenced_packages`).
- ~288 GETs/dia/usuário ao `/version.json` (payload ~30 B, `no-cache`). Custo desprezível.

### Trade-offs aceitos
- O reload é "duro" (`window.location.reload()`): o usuário perde estado de tela não
  persistido. Aceitável para o MVP — a sessão Sanctum sobrevive (cookie same-origin,
  ADR-007 §F5) e as telas atuais não têm estado caro a preservar.
- Em `dev` a feature fica invisível; valida-se com `--dart-define=APP_VERSION` em build de
  teste / E2E e no smoke de homolog (CA-17).

## Como verificar (se aplicável)

- `curl -I https://app.homolog.turni.com.br/flutter_service_worker.js` retorna
  `Cache-Control: no-cache, no-store, must-revalidate` (a outra metade da causa-raiz).
- Smoke mobile CA-17: com uma aba aberta numa release `rc.M`, publicar `rc.M+1`; em ≤ 5 min
  (ou ao voltar do background) o banner aparece e "Atualizar agora" carrega o `rc.M+1`.
- **Sinal de revisão:** se o banner for percebido como intrusivo em homolog (PO/teste
  mobile), reduzir a frequência ou trocar por badge silencioso no rodapé com versão
  clicável → "Atualizar". Não fazer ainda.

## Emenda (2026-05-31) — "Atualizar agora" não funcionava no iOS/desktop: causa-raiz e workaround

Validando o smoke CA-17 em homolog (rc.29 → rc.30), o banner aparecia (detecção OK), mas
"Atualizar agora" **recarregava a MESMA versão** — em iOS (Safari e Chrome) **e** em desktop
mesmo com force-reload. Causa-raiz confirmada por `curl`:

- O `index.html` é `no-cache`, mas referencia `flutter_bootstrap.js` → `main.dart.js`, que têm
  **nome de arquivo fixo (sem hash de conteúdo)** e estavam sendo servidos como
  `public, max-age=31536000, immutable` (apanhados pelo glob `**/*.@(js|css|wasm)` do `firebase.json`).
  O navegador então **nunca re-busca** esses arquivos por 1 ano → o reload reabre o bundle velho.
- O `skipWaiting` não salvava: o sinal de versão nova vem do polling do `version.json`
  (independente do ciclo do SW), então no clique quase nunca há SW em `waiting`; e no iOS
  (WKWebView) os eventos de SW (`controllerchange`) são instáveis.

**Decisões da emenda:**

1. **`firebase.json`** passa a servir os arquivos de entrada de nome fixo do Flutter
   (`main.dart.js`, `flutter.js`, `flutter_bootstrap.js`, `flutter_service_worker.js`) com
   `no-cache, no-store, must-revalidate` (bloco depois do glob immutable — last-wins), nos dois
   targets. Os assets com hash (`canvaskit/`, `assets/`) seguem `immutable`.
2. **`ServiceWorkerBridge` (web)** abandona `skipWaiting`/`controllerchange` e passa a fazer
   **`getRegistrations().unregister()` + limpar todo o Cache Storage + `location.reload()`** —
   determinístico, sem depender de evento de SW. Sem SW controlando, o reload busca o entry chain
   (agora no-cache) da rede e pega a versão nova. A página recarregada registra um SW novo.

**Consequência:** a cada "Atualizar agora" o cache offline é descartado e re-baixado no próximo
load (aceitável — é ação explícita e rara; o MVP não tem requisito offline). Migração: aparelhos
presos numa versão **anterior à correção** (≤ rc.30) precisam de **uma** limpeza manual única
para chegar na primeira versão corrigida; a partir dela, "Atualizar agora" funciona sozinho.

## Tipo

- [ ] **Padrão transversal**: lib/abordagem que vira default no projeto.
- [x] **Workaround**: contornar limitação de plataforma (iOS/WKWebView + cache immutable de
  arquivos de entrada de nome fixo do Flutter) — ver emenda 2026-05-31.
- [x] **Convenção interna**: padrão de implementação local da auto-atualização do WebApp
  (parâmetros operacionais + conditional import para interop web).
- [ ] **Otimização**: mudança feita por motivo de performance, com medição.
- [ ] **Refatoração estrutural**: mudança que afeta vários módulos por motivo de qualidade.

---

## Histórico

- 2026-05-30 — criada como `proposed` por programador (sessão programador-claude) durante STORY-037
- 2026-05-31 — emenda com a causa-raiz do "Atualizar agora" não trocar de versão (cache immutable do entry chain + SW instável no iOS) e o workaround (entry chain no-cache + bridge desregistra SW/limpa caches)
- 2026-05-31 — `accepted` por Alexandro (PO) após validação do smoke CA-17 em homolog (rc.31 → rc.32 no celular)
