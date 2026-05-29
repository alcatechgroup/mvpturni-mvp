---
epic_id: EPIC-006
slug: landing-institucional
title: Landing institucional turni.com.br — deploy AS IS sob responsabilidade do marketing
wave: WAVE-2026-01
status: done
owner_role: po
created_at: 2026-05-28
updated_at: 2026-05-29
closed_at: 2026-05-29
target_completion: 2026-07-31  # estimativa orientativa; soft-cap, não prazo
---

# EPIC-006 — Landing institucional turni.com.br

## Por que existimos (problema do usuário)

Quem busca o Turni hoje cai no protótipo navegável dentro de `docs/prototipo/` — material de demo interna, não produto público. A WAVE-2026-01 entrega o ciclo do turno em homologação (PDR-011), mas não existe **endereço público** para onde apontar o tráfego que começa a chegar a `turni.com.br`. Hoje o domínio principal resolve para nada.

A landing já existe e está pronta — vive em `docs/prototipo/index.html`, é de **propriedade e responsabilidade do time de marketing**, e está fora do escopo de produto/engenharia mexer no conteúdo. **Mas o time comercial ainda não autorizou a exposição pública** dessa landing: lançá-la aberta no apex queima a janela de comunicação que o comercial está orquestrando (parcerias em negociação, contratos âncora ainda não fechados, narrativa de lançamento sendo desenhada). O domínio precisa responder com algo institucional e neutro — uma página **"Em breve"** com a identidade visual do Turni — enquanto a landing completa permanece acessível apenas por um **path secreto** que o comercial compartilha com quem precisa ver (parceiros, investidores, imprensa sob NDA).

O que falta é o caminho **operacional** para colocar isso no ar: hosting dedicado, domínios apontados, gate "Em breve" no apex, landing completa atrás de path obscuro, e CI/CD que respeita a fronteira "marketing edita conteúdo, engenharia não toca". Este épico fecha esse caminho.

## Resultado esperado (outcome)

Ao fim deste épico:

- `https://turni.com.br/` serve uma página **"Em breve"** institucional — minimalista, com logo e identidade visual da landing (cores, tipografia, mark TURN**I.**), mensagem curta de "estamos chegando" e nada mais. Sem CTAs, sem formulário, sem links que vazem o restante do site. **Indexável** pelos buscadores (esta página é o que o Google deve mostrar para `site:turni.com.br`).
- `https://turni.com.br/<path-secreto>/` serve a landing completa **AS IS** (mesmo HTML/CSS/JS que está em `docs/prototipo/index.html` hoje, com as adaptações mecânicas mínimas — ver "Adaptação mínima permitida" abaixo). O valor exato de `<path-secreto>` é definido **fora deste documento** (ADR-012 acomoda; pode ser commitado em `firebase.json` se aceito o trade-off, ou injetado via variável de deploy se for tratado como segredo operacional).
- `https://www.turni.com.br` faz **redirect 301** para `https://turni.com.br/` (apex canônica — cai no "Em breve", não no path secreto).
- O mesmo padrão vive em homologação (`landing.homolog.turni.com.br/` → "Em breve"; `landing.homolog.turni.com.br/<path-secreto>/` → landing completa) para o marketing/comercial validar antes de promover.
- A landing completa tem **`noindex`** (meta tag + `robots.txt` que faz `Disallow: /<path-secreto>/`), garantindo que buscadores não a indexem mesmo que o path vaze acidentalmente em log/referrer.
- A landing roda em **Firebase Hosting site dedicado** (separado dos sites `turni-webapp-*` do WebApp), com pipeline de deploy próprio que não acopla release de marketing a release de produto.
- A fronteira de responsabilidade está documentada e codificada: marketing edita o conteúdo da landing em `apps/landing/public/<path-secreto>/` e abre PR; engenharia mantém a página "Em breve" e a infra de routing; o comercial controla quando o `<path-secreto>` é "promovido" para ser o apex (decisão fora do escopo deste épico — vira um item operacional de "go-public").

### Honestidade sobre o gate

`<path-secreto>` é **obfuscação, não segurança**. Quem souber, descobrir, ou achar o path por logs/referrer/Wayback consegue ver a landing. Isso é aceitável para o propósito declarado (não estar no índice do Google nem no apex enquanto o comercial fecha narrativa de lançamento) e é o trade-off explicitamente aceito por este épico. Se o comercial precisar de **proteção real** (não vazar para quem não foi convidado), o caminho é basic-auth ou IP allowlist via Firebase Hosting/Cloud Armor — fica como ampliação fora deste épico.

## Métrica de sucesso (como saberemos que funcionou)

- **Primária — gate "Em breve" responde no apex:** `curl -sI https://turni.com.br/` retorna `200` com a página "Em breve" (verificado pelo `<title>` ou marcador único no HTML); `curl -sI https://www.turni.com.br/` retorna `301` com `Location: https://turni.com.br/`. Verificado de fora da rede do Turni.
- **Landing AS IS acessível só pelo path secreto:** `curl -s https://turni.com.br/<path-secreto>/` retorna `200` com o HTML da landing original (verificável pelo `<title>` "TURNI · MVP Demo" ou marcador equivalente); `curl -sI https://turni.com.br/<path-aleatorio-qualquer>/` retorna a página "Em breve" (não 404 — a SPA-like rewrite trata qualquer path desconhecido como apex) **ou** um 404 institucional na identidade da landing (decisão da ADR-012).
- **Não indexável pelo Google:** `curl -s https://turni.com.br/robots.txt` contém `Disallow: /<path-secreto>/`; a landing carrega `<meta name="robots" content="noindex,nofollow">`. A página "Em breve" pode ser indexada normalmente.
- **Sem vazamento por link interno:** a página "Em breve" não contém referência alguma ao `<path-secreto>` (verificável por grep no HTML servido). Nenhum sitemap.xml expõe o path.
- **Isolamento operacional:** um deploy da landing **não derruba nem redeploya** o WebApp/API/Admin. Validado em homologação alterando um arquivo da landing e observando que `app.homolog.turni.com.br` continua na release anterior.
- **CTA rastreável (dentro da landing secreta):** os CTAs `Cadastre-se`, `Sou TURNI`, `Cadastrar empresa`, `Já sou TURNI` (e demais botões hoje apontando para `app.html#/...`) levam a páginas equivalentes do WebApp em homologação, sem 404 intermediário.
- **Lighthouse mínimo defensável:** Performance ≥ 70 e Accessibility ≥ 80 em mobile (3G simulado), medido na landing secreta. Página "Em breve" precisa marcar Performance ≥ 90 (é trivial e leve por construção). Não-bloqueante para fechamento se a landing já estava abaixo no protótipo — marketing assume o débito, mas o número precisa estar **registrado** para ter linha-base.
- **Trilha de auditoria:** todo deploy tem tag git, autor, timestamp e hash do bundle no histórico do Firebase Hosting (rollback por release anterior viável). "Em breve" e landing fazem parte do mesmo bundle e da mesma release.

## Entregável visível no fim do épico

- [ ] Pasta `apps/landing/` no monorepo com a estrutura:
  - `apps/landing/public/index.html` — página **"Em breve"** (NOVA, criada neste épico — não é AS IS), minimalista, usando os tokens visuais da landing original (mesmas variáveis CSS `--logo-green`, `--black`, `--text`, fonte `Bebas Neue` no logo, Inter no corpo). Conteúdo: logo TURN**I.**, mensagem curta ("Em breve.", "Aguarde." ou texto fornecido pelo marketing), nada mais. Sem CTAs, sem formulário, sem links de saída para outros paths do site.
  - `apps/landing/public/<path-secreto>/` — snapshot AS IS de `docs/prototipo/` (apenas a landing — `index.html`, `manifest.json`, `sw.js`, `tour.css`, `tour.js`, `img/`, `turnioficial_files/`), **sem** `app.html` (esse pertence ao protótipo do WebApp e fica fora da landing).
  - `apps/landing/public/robots.txt` com `Disallow: /<path-secreto>/`.
  - `apps/landing/public/404.html` — institucional na identidade da landing, sem link de volta ao path secreto.
- [ ] Os CTAs `href="app.html#/..."` da landing AS IS ajustados para o WebApp em homologação (`https://app.homolog.turni.com.br/#/...`) — única mudança permitida no conteúdo da landing, executada uma vez na importação. Documentada como "adaptação de wiring" em CHANGELOG da landing.
- [ ] `<meta name="robots" content="noindex,nofollow">` injetado no `<head>` da landing AS IS (segunda exceção à regra "não tocar conteúdo" — necessária para o gate).
- [ ] Novo Firebase Hosting site `turni-landing-homolog` (e `turni-landing-prod` definido em código, aplicado conforme calendário do cutover de produção) provisionado via Terraform, no mesmo projeto GCP `turni-mvp`.
- [ ] `.firebaserc` e `firebase.json` da raiz estendidos com alvos `landing-homolog` / `landing-prod`, sem afetar os alvos `homolog` / `prod` do WebApp. `firebase.json` do site da landing **não** tem rewrite genérico `** → /index.html` (isso quebraria o gate — qualquer path desconhecido cairia na landing). Em vez disso: rotas explícitas para `/`, `/<path-secreto>/**`, `/robots.txt`; fallback 404 → `404.html`.
- [ ] Cloud DNS gerencia: `turni.com.br` (A/AAAA → Firebase Hosting site `turni-landing-prod`), `www.turni.com.br` (redirect 301 para apex via Firebase Hosting redirect rule), `landing.homolog.turni.com.br` (CNAME → site homolog).
- [ ] Workflow GitHub Actions dedicado à landing: trigger por path filter em `apps/landing/**`, build trivial (cópia de estáticos), deploy em homolog em push para tag `landing-vX.Y.Z-rc.N`, deploy em prod em tag `landing-vX.Y.Z` com gate humano de 1 clique (mesmo padrão tag-based da ADR-004, mas com namespace `landing-` para não cruzar com tags do produto).
- [ ] `CODEOWNERS` da raiz define escopo dividido em `apps/landing/`:
  - `apps/landing/public/<path-secreto>/**` → marketing (ou alias `@turni/marketing`) — conteúdo da landing.
  - `apps/landing/public/index.html` (página "Em breve"), `firebase.json`, `404.html`, `robots.txt`, workflow de deploy → engenharia.
- [ ] `apps/landing/README.md` explicando a fronteira: "este diretório é de propriedade do marketing **dentro de `<path-secreto>/`**; a página `Em breve` no apex e a infra de routing são de engenharia. Comercial decide quando promover."
- [ ] Runbook em `docs/operacao/runbook-landing.md` cobrindo: como o marketing publica conteúdo, como engenharia faz rollback de emergência, como **trocar o `<path-secreto>`** (rotação se vazar), como adicionar/trocar domínio, como **promover** a landing para o apex (procedimento "go-public" — fora deste épico mas o runbook descreve o passo).

## Adaptação mínima permitida no conteúdo AS IS

A landing (o que vive em `<path-secreto>/`) entra **AS IS** — engenharia não reescreve, não redesenha, não "melhora". Mas a importação inicial exige **quatro adaptações mecânicas obrigatórias**, executadas uma vez na STORY de import e nunca mais:

1. **CTAs para `app.html#/...`** viram `https://app.homolog.turni.com.br/#/...` (e na promoção a produção viram `https://app.turni.com.br/#/...` via build-time substitution ou release manual — a decisão fica na ADR-012).
2. **Remoção de `app.html` e quaisquer assets exclusivos do protótipo do WebApp** que estejam misturados em `docs/prototipo/` — só a landing (`index.html` + assets referenciados por ela) viaja para `apps/landing/public/<path-secreto>/`.
3. **`<meta name="robots" content="noindex,nofollow">`** injetado no `<head>` — exigido pelo gate. Mesmo que o path vaze, buscadores não indexam.
4. **Headers de cache e segurança mínimos** (CSP básica, HSTS, Cache-Control nos estáticos) configurados em `firebase.json` do site da landing — não tocam HTML, só headers HTTP.

Qualquer outra mudança no HTML/CSS/JS/copy/imagem da landing é **proibida** neste épico e é responsabilidade exclusiva do marketing via PR para `apps/landing/public/<path-secreto>/`.

A página **"Em breve"** (`apps/landing/public/index.html`) **não** é AS IS — é um artefato novo, criado por engenharia (ou marketing, se preferir entregar pronta) reaproveitando os tokens visuais da landing original. Tem ciclo de vida próprio: enquanto o comercial não autorizar exposição, ela é o que o mundo vê em `turni.com.br/`. No "go-public" futuro, esta página é descartada (ou virara redirect 301 para `/` que passa a servir a landing).

## Fora de escopo (explicitamente)

- **Reescrita, refator ou redesign da landing** — vive AS IS até o marketing pedir mudança.
- **Go-public (promoção da landing para o apex)** — comercial decide o momento. Quando acontecer, vira novo item operacional (release de configuração + remoção da página "Em breve" + ajustes de robots/sitemap). Este épico só **viabiliza** essa promoção como operação de minutos, não a executa.
- **Formulário de captura de email no "Em breve"** ("avisem-me quando lançar") — fora; comercial pode pedir como ampliação separada se quiser capturar lead. Backend de formulário (newsletter, lead, fale conosco) na landing AS IS continua fora também (se tiver formulário, aponta para Typeform/Tally/`mailto:`).
- **Proteção real do path secreto** (basic-auth, IP allowlist, signed URL) — fora. O gate é obfuscação, conforme declarado em "Honestidade sobre o gate". Se o comercial precisar de proteção real, vira ampliação separada.
- **Analytics / GTM / Hotjar / pixel de mídia paga** — marketing configura via tag manager depois; este épico não inclui setup de plataforma de analytics, nem na "Em breve" nem na landing.
- **i18n / versão em inglês** — landing nasce só pt-BR.
- **A/B testing infra** — fora do MVP.
- **Cookie banner LGPD com gestão de consentimento real** — se a landing AS IS já tem aviso, fica; setup de CMP plug-and-play fica para épico futuro.
- **CDN customizada além da que o Firebase Hosting já oferece** (Cloudflare na frente, etc.) — Firebase Hosting CDN é suficiente.
- **PWA / Service Worker da landing** — `sw.js` viaja AS IS se já estiver no protótipo, mas não há esforço de engenharia para corrigir/manter. Se gerar problema (cache agressivo escondendo deploy novo do marketing **ou** vazando o path secreto para visitantes que digitam `/`), a primeira ação de remediação é **remover o `sw.js`**, não consertá-lo.
- **WebApp em produção** — landing aponta para WebApp em **homologação** nesta onda. Swap para `app.turni.com.br` (prod) acontece no épico de cutover de produção (WAVE-2026-02) e é tratado lá como item próprio, não aqui.

## Referências da especificação

- `docs/prototipo/index.html` — fonte do conteúdo AS IS da landing (somente esta página + assets referenciados — `manifest.json`, `sw.js`, `tour.css`, `tour.js`, `img/`, `turnioficial_files/`). `app.html` **não** faz parte do escopo.
- `docs/project-state/decisions/adr/ADR-004-hospedagem-iac-deploy.md` — Firebase Hosting + Terraform + GitHub Actions tag-based + gate humano de 1 clique em prod. A landing herda esse padrão integralmente; só muda o namespace de tags (`landing-vX.Y.Z`) e o nome dos sites Firebase (`turni-landing-*`).
- `docs/project-state/decisions/adr/ADR-003-monorepo-vs-polirepo.md` — monorepo poliglota com deploy independente por path filter. `apps/landing/**` ganha seu próprio path filter, isolado de `apps/webapp/`, `apps/admin/`, `apps/api/`.
- `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` — define WebApp e Backoffice; a landing é **terceira superfície pública**, complementar e isolada de ambas.
- `docs/project-state/decisions/pdr/PDR-011-escopo-da-wave-2026-01.md` — a landing institucional não bloqueia o ciclo do turno em homologação, mas roda nesta onda em paralelo para destravar campanhas de pré-cadastro do marketing.
- `infra/modules/firebase/main.tf` — módulo Terraform de Firebase Hosting já existente; vai aceitar instâncias múltiplas (uma para WebApp, outra para landing).
- `infra/modules/dns/main.tf` — Cloud DNS para `turni.com.br`; vai ganhar registros para apex (A/AAAA), `www` (redirect) e `landing.homolog`.

## Dependências

- **Bloqueia**: nada na WAVE-2026-01 (pode rodar em paralelo a EPIC-001..005). Habilita campanhas de pré-cadastro e mídia paga do marketing a partir do momento em que `turni.com.br` estiver respondendo. Estabelece o padrão de "site estático em Firebase Hosting site dedicado" que pode ser replicado depois (ex: blog, docs públicas, status page).
- **Bloqueado por**: nada bloqueante. Aproveita infra já existente (projeto GCP `turni-mvp`, módulos Terraform, pipeline GitHub Actions, Cloud DNS com zona `turni.com.br`). Idealmente sequenciado **depois** da STORY-007 do EPIC-000 estar fechada (Firebase Hosting do WebApp já no ar comprovando o caminho), o que já aconteceu — EPIC-000 está `done`.
- **Decisões arquiteturais necessárias** (a serem registradas em ADR-012 — "Landing institucional: gate Em breve, path secreto, hosting dedicado, pipeline isolado"):
  - Mecanismo do gate "Em breve" + path secreto: rotas explícitas em `firebase.json` (sem rewrite genérico para `/index.html`) **vs.** subdomínio dedicado para a landing (ex: `<path-secreto>.turni.com.br`) **vs.** dois sites Firebase separados (um para apex/"Em breve", outro para `<path-secreto>` via subdomínio).
  - Valor inicial e política de rotação do `<path-secreto>` (commitado no `firebase.json` **vs.** injetado via secret de deploy; rotação manual via runbook **vs.** automática por janela).
  - Política de tratamento de 404: página institucional na identidade da landing **vs.** redirect para "Em breve" (a primeira evita falsos positivos de "site quebrado"; a segunda esconde a estrutura).
  - Como o redirect `www → apex` é implementado (regra do Firebase Hosting via `redirects` no `firebase.json` **vs.** registro DNS via servidor de redirect externo).
  - Como o swap de URL de CTA `homolog → prod` é feito quando o WebApp prod subir (substituição build-time com placeholder **vs.** PR manual do marketing **vs.** redirect HTTP em `app.homolog → app.turni`).
  - Política de cache do `index.html` ("Em breve") e do `index.html` da landing (no-cache vs. short TTL) para garantir que push aparece em ≤ 5 min.
  - Se o `sw.js` da landing AS IS fica ou é removido (decisão depende do que ele cacheia hoje — se forçar reload de versão antiga ou puder vazar HTML do path secreto para visitantes do apex, sai).
  - Como o `CODEOWNERS` separa responsabilidade entre marketing (`<path-secreto>/`) e engenharia ("Em breve", infra, routing).
- **Decisões de produto necessárias** (a serem registradas em PDR-015 — "Fronteira de responsabilidade: landing é do marketing, gate e infra são da engenharia, go-public é do comercial"):
  - Quem aprova merge em `apps/landing/public/<path-secreto>/**` (CODEOWNERS define, PDR registra o acordo).
  - Quem aprova mudança na página "Em breve" (engenharia ou marketing? — recomendação: engenharia mantém, marketing pode pedir ajuste de copy via PR).
  - **Quem decide o go-public e como** — comercial autoriza, mas o ato técnico (remover gate, promover landing para apex) é de engenharia. Como esse handoff acontece?
  - O que acontece se o `<path-secreto>` vazar (rotação imediata? notificação ao comercial? log de quem teve acesso?).
  - O que acontece se marketing quebrar a landing (rollback automático em falha de health-check? SLA de resposta da engenharia?).
  - Cadência de release da landing (sob demanda vs. janela fixa).

## Estórias

Decomposição final feita em 2026-05-28 (épico saiu de `draft` para `ready`). Oito estórias cobrem o épico ponta a ponta:

| ID | Título | Tipo | Papel | Tamanho | Bloqueada por | Bloqueia |
|---|---|---|---|---|---|---|
| [STORY-026](stories/STORY-026-spike-gate-em-breve-path-secreto-topologia-firebase.md) | Spike Arquiteto — gate "Em breve" + path secreto + topologia Firebase (ADR-012) | spike | arquiteto | M | — | 028, 029, 030, 031 |
| [STORY-027](stories/STORY-027-pdr-fronteira-marketing-engenharia-comercial.md) | PO — PDR-015 Fronteira marketing × engenharia × comercial | decision | po | S | — | 030, 032 |
| [STORY-028](stories/STORY-028-pagina-em-breve-com-identidade-visual.md) | Página "Em breve" com identidade visual da landing | implementation | programador (+designer) | S | 026 | 030, 031 |
| [STORY-029](stories/STORY-029-terraform-firebase-multi-site-e-dns-apex-www-landing.md) | Terraform — Firebase multi-site + DNS apex/www/landing.homolog | implementation | programador | M | 026 | 031, 032, 033 |
| [STORY-030](stories/STORY-030-scaffolding-apps-landing-import-as-is-adaptacoes-minimas.md) | Scaffolding apps/landing/ + import AS IS + 4 adaptações + robots/404/README/CODEOWNERS | implementation | programador | M | 026, 027, 028 | 031, 032, 033 |
| [STORY-031](stories/STORY-031-firebase-json-rotas-explicitas-firebaserc-e-workflow-deploy.md) | firebase.json com rotas explícitas + .firebaserc + workflow GitHub Actions tag-based | implementation | programador | M | 029, 030 | 032, 033 |
| [STORY-032](stories/STORY-032-runbook-operacional-landing.md) | Runbook operacional — publicar, rollback, rotação de path, go-public | implementation | programador | S | 027, 029, 030, 031 | 033 |
| [STORY-033](stories/STORY-033-validacao-final-epic-006.md) | Validação final do EPIC-006 | validation | validador | S | 026-032 | (fechamento do épico) |

**Caminho crítico**: 026 → 029 → 030 → 031 → 032 → 033 (6 estórias). 027 e 028 podem rodar em paralelo com 026/029, encurtando o cronograma se houver capacidade. Sizing total: 3M + 5S — épico pequeno, cabe num único sprint com folga se as 4 estórias do meio rodarem em paralelo.

**Pré-requisito de entrada em sprint**: ADR-012 (STORY-026) **deve estar `accepted`** antes que 028/029/030/031 possam ser iniciadas — sem ela, decisões de mecânica ficam ad-hoc. PDR-015 (STORY-027) **deve estar `accepted`** antes que 030 toque CODEOWNERS e antes que 032 escreva o runbook. Recomendação operacional: agendar 026 e 027 nos primeiros dias da sprint para destravar as demais.

## Validação final

Critérios em `validation/checklist.md` (15 blocos: pré-condições, decisões aceitas, Em breve, landing AS IS, robots, gate, não-leak, CODEOWNERS, pipeline tag-based, isolamento, rollback, Terraform multi-ambiente, headers, redirect www, runbook, consistência do index.json). Relatório do validador em `validation/report.md`.

**Definição de épico concluído**:
1. `https://turni.com.br/` responde `200` com a página "Em breve" (verificável por marcador único no HTML), fora da rede do Turni.
2. `https://turni.com.br/<path-secreto>/` responde `200` com a landing AS IS (verificável por `<title>` "TURNI · MVP Demo" ou marcador equivalente), fora da rede do Turni.
3. `https://www.turni.com.br/` responde `301` para `https://turni.com.br/` (apex com "Em breve", não para o path secreto).
4. `https://turni.com.br/robots.txt` contém `Disallow: /<path-secreto>/`; a landing carrega `<meta name="robots" content="noindex,nofollow">`.
5. Nenhum link da página "Em breve" aponta para `<path-secreto>` (grep no HTML servido); nenhum sitemap.xml expõe o path.
6. `https://landing.homolog.turni.com.br/` espelha o comportamento de produção (apex → "Em breve"; `/<path-secreto>/` → landing).
7. Deploy isolado: alterar arquivo em `apps/landing/` e abrir release não dispara redeploy de WebApp/API/Admin.
8. CTAs da landing secreta levam ao WebApp em homologação sem 404.
9. Firebase Hosting tem release history visível; rollback exercitado em homolog.
10. CODEOWNERS direciona PR de `apps/landing/public/<path-secreto>/**` para revisor de marketing; PR em `apps/landing/public/index.html` (Em breve) e em `firebase.json` para engenharia.
11. Relatório do validador `approved` (ou `approved_with_pending` com débitos não-bloqueantes documentados).

## Histórico

- 2026-05-28 — criado por PO durante WAVE-2026-01, em resposta a pedido do Alexandro para destravar o domínio `turni.com.br` em paralelo ao ciclo do turno em homologação. Decisões de produto fixadas via questionário: Firebase site dedicado no mesmo projeto GCP `turni-mvp`; CTAs apontam para WebApp homolog (swap no cutover de produção); landing sobe em homolog + prod; épico roda na WAVE-2026-01 em paralelo.
- 2026-05-28 (ajuste pós-revisão com comercial) — comercial não autorizou exposição pública da landing no apex enquanto a narrativa de lançamento está sendo orquestrada. Épico re-escopado: apex e `www` passam a servir página **"Em breve"** com identidade visual da landing (artefato novo, fora do AS IS); landing completa AS IS fica acessível **apenas** atrás de `<path-secreto>` configurado fora deste documento; `noindex` + `robots.txt Disallow` evitam indexação acidental. Honestidade declarada: gate é obfuscação, não segurança — proteção real (basic-auth/IP allowlist) fica como ampliação separada se comercial pedir. Decisões pendentes deslocadas para ADR-012 (mecânica do gate, política de rotação, tratamento de 404) e PDR-015 (fronteira ampliada para incluir comercial — quem decide o go-public, o que fazer se o path vazar). Reservei PDR-015 porque PDR-014 está ocupado pela decisão de AceiteEletronico (EPIC-001).
- 2026-05-28 (decomposição em estórias) — épico decomposto em 8 estórias (STORY-026 a STORY-033), `validation/checklist.md` redigido com 15 blocos, status alterado de `draft` para `ready`. Estórias seguem padrão dos épicos anteriores (EPIC-001 como referência): contexto detalhado, CAs observáveis, fora-de-escopo explícito, padrões de qualidade, dependências, decisões já tomadas, DoD, protocolo do agente, seção de notas. Caminho crítico 026→029→030→031→032→033 (6 estórias); 027 e 028 paralelizáveis. Sizing total 3M+5S — cabe em um único sprint. Pré-requisito de entrada: ADR-012 (STORY-026) e PDR-015 (STORY-027) precisam estar `accepted` cedo na sprint para destravar as demais.
