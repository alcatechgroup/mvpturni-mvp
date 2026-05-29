---
story_id: STORY-032
slug: runbook-operacional-landing
title: Runbook operacional da landing — publicar, rollback, rotação de path, go-public
epic_id: EPIC-006
sprint_id: SPRINT-2026-W24-LANDING
type: implementation
target_role: programador
requires_design: false
status: done
owner_agent: programador
created_at: 2026-05-28
updated_at: 2026-05-29
estimated_session_size: S
---

# STORY-032 — Runbook operacional da landing

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

ADR-012 decidiu a topologia; STORY-029 provisionou; STORY-030 organizou os arquivos; STORY-031 montou o pipeline. Agora existe um sistema funcionando, com **vários procedimentos operacionais** que precisam estar documentados para que qualquer pessoa do time (engenharia ou marketing) consiga executar sem improvisar:

- **Publicar conteúdo** (marketing edita HTML/CSS/JS/imagem, abre PR, mergeia, taggea release).
- **Rollback emergencial** (push do marketing quebrou a landing — engenharia reverte para release anterior em minutos).
- **Rotacionar o `<path-secreto>`** (PDR-015 dispara rotação se vazar; engenharia executa).
- **Trocar/adicionar domínio** (subdomínio futuro, redirect novo, etc.).
- **Remover sw.js de emergência** (se o service worker AS IS começar a vazar HTML antigo ou esconder push novo).
- **Go-public** (comercial autoriza; engenharia executa: flip Terraform `landing_prod_enabled = true`, swap CTAs `homolog → prod`, remoção do gate, atualização do robots.txt).

PDR-015 fixa **quem decide o quê**; este runbook fixa **como cada coisa é feita tecnicamente**. Sem o runbook, o protocolo de PDR-015 vira improviso quando precisa rodar.

A estória é **S** porque é redação de documentação técnica baseada em decisões e implementações já feitas — nada novo é decidido aqui, apenas escrito.

- Épico: `docs/project-state/epics/EPIC-006-landing-institucional/epic.md`
- Documentos canônicos a ler ANTES de redigir:
  - `epic.md` do EPIC-006 (seção "Entregável visível" lista `docs/operacao/runbook-landing.md` como entregável)
  - `docs/project-state/decisions/adr/ADR-012-landing-gate-em-breve-path-secreto.md` (mecânica decidida)
  - `docs/project-state/decisions/pdr/PDR-015-fronteira-marketing-engenharia-comercial-landing.md` (protocolos de processo — quem decide go-public, rotação, SLA)
  - `docs/operacao/runbook-homolog.md` (precedente — formato de runbook do projeto)
  - `infra/envs/homolog/main.tf` + `infra/envs/prod/main.tf` pós STORY-029 (variable `landing_prod_enabled`)
  - `firebase.json` + `.firebaserc` + `.github/workflows/landing-deploy.yml` pós STORY-031 (comandos a documentar)
  - `apps/landing/README.md` pós STORY-030 (fronteira de propriedade — runbook complementa)
  - `docs/skills/programador/SKILL.md`

## O quê (objetivo desta estória)

Entregar `docs/operacao/runbook-landing.md` cobrindo **7 procedimentos operacionais**, cada um com pré-condições, passos numerados executáveis, comandos exatos, verificações pós-execução, e quem pode executar:

1. **Procedimento P1 — Publicar conteúdo da landing (marketing).**
   - Pré-condição: PR mergeado em `main` com conteúdo novo em `apps/landing/public/<path-secreto>/`.
   - Passos: criar tag `landing-vX.Y.Z-rc.N` apontando para o commit de merge; push da tag; workflow dispara automaticamente; smoke test pós-deploy verde; site atualizado em `landing.homolog.turni.com.br/<path-secreto>/` em ≤ 5 min.
   - Verificação: `curl` retornando conteúdo novo; preview no navegador.
   - Quem executa: marketing (com permissão de push de tag) ou engenharia (sempre).
   - SLA: deploy em homolog ≤ 5 min após push da tag (propagação de HTML `no-cache` definida em ADR-012 §4).

2. **Procedimento P2 — Rollback emergencial (engenharia).**
   - Pré-condição: deploy quebrou a landing (smoke test falhou e workflow auto-reverteu) OU defeito detectado pós-deploy (smoke test passou mas humano vê problema).
   - Passos: identificar release anterior via console Firebase Hosting (`firebase hosting:channel:list` ou console web); executar `firebase hosting:rollback --site turni-landing-homolog` (ou `--site turni-landing-prod`); verificar `curl` retornando conteúdo anterior; comunicar marketing via canal acordado em PDR-015.
   - Quem executa: qualquer engenheiro com acesso ao Firebase Hosting CLI seguindo runbook (não precisa de aprovação humana adicional — rollback é reversão segura).
   - SLA: **best-effort, sem número fixo** (PDR-015 §4 — time solo, sem on-call; rollback é prioridade sobre trabalho não-urgente; risco baixo porque a "Em breve" no apex independe do conteúdo AS IS).

3. **Procedimento P3 — Rotacionar `<path-secreto>` (engenharia, gatilho do comercial).**
   - Pré-condição: comercial confirma vazamento ou rotação preventiva agendada (PDR-015 define o gatilho exato).
   - Passos:
     a. Comercial define novo path (via canal acordado, registrado).
     b. Engenharia atualiza secret `LANDING_SECRET_PATH` no GitHub Actions (homolog primeiro).
     c. Engenharia atualiza Terraform se aplicável (mecânica decidida em ADR-012 — pode ou não envolver Terraform).
     d. Engenharia move conteúdo: `git mv apps/landing/public/<path-secreto-antigo>/ apps/landing/public/<path-secreto-novo>/` em PR.
     e. Engenharia atualiza `robots.txt` para apontar `Disallow: /<path-secreto-novo>/`.
     f. PR aprovado; merge; tag `landing-vX.Y.Z-rc.N`; deploy homolog; smoke test verde com novo path.
     g. Mesmo procedimento em prod se aplicável (com gate humano).
     h. Comunicação: enviar novo path aos detentores legítimos via canal acordado; declarar path antigo morto (Firebase Hosting servirá 404 institucional para `<path-secreto-antigo>/`).
   - Quem executa: engenharia (passos b-g); comercial (passos a, h).
   - SLA: **sob demanda, sem prazo fixo** (PDR-015 §6 — o gate é obfuscação, não segurança; vazamento não é incidente de segurança cronometrado; rotação acontece quando o comercial pedir e a engenharia conseguir executar).
   - Verificação: `curl /<path-secreto-antigo>/` → 404; `curl /<path-secreto-novo>/` → 200 com landing.

4. **Procedimento P4 — Trocar/adicionar domínio.**
   - Pré-condição: comercial autoriza novo domínio ou subdomínio (ex: `marketing.turni.com.br`); domínio existe ou foi registrado.
   - Passos: adicionar registro DNS via Terraform (`infra/modules/dns` + `infra/envs/<env>/main.tf`); adicionar `custom_domain` ao site Firebase via `infra/modules/firebase`; `terraform plan` revisado; `terraform apply`; aguardar Firebase validar custom domain (alguns minutos); `firebase deploy --only hosting:<target>` se conteúdo precisar atualizar; verificar `dig` e `curl`.
   - Quem executa: engenharia (com PR aprovado pelo PO).
   - SLA: depende da janela de mudança DNS (TTL); planejar com pelo menos 1h de antecedência.

5. **Procedimento P5 — Remover `sw.js` de emergência.**
   - Pré-condição: detectado que service worker está cacheando agressivamente (push do marketing não aparece) ou vazando conteúdo (visitante do apex vê conteúdo da landing antiga).
   - Passos: PR removendo `apps/landing/public/<path-secreto>/sw.js`; ajustar `apps/landing/public/<path-secreto>/index.html` removendo o registro de service worker (`<script>` de `navigator.serviceWorker.register`); adicionar resposta 404 explícita em `firebase.json` para `/<path-secreto>/sw.js` para que browsers que cacheiam o registro recebam 404 e desinstalem; merge + tag + deploy.
   - Quem executa: engenharia.
   - SLA: **best-effort** (mesmo regime do rollback, PDR-015 §4).
   - Nota: ADR-012 §5 já decidiu remover o sw.js na importação (STORY-030); P5 é vigilância pós-fato / kill-switch caso algum SW persista em clientes.

6. **Procedimento P6 — Go-public (comercial autoriza, engenharia executa).**
   - Pré-condição: comercial comunica autorização de go-public via canal acordado em PDR-015 (issue/PR/mensagem registrada) com data alvo (**≥ 24h de antecedência** por PDR-015 §7). Pré-condição adicional: WebApp em produção (`app.turni.com.br`) já no ar — o swap de CTA depende do cutover de produção (WAVE-2026-02); sem ele, o go-public fica bloqueado pelo cutover, não pela landing.
   - Passos:
     a. **Ao receber a autorização (T ≥ 24h):** engenharia abre PR de preparação:
        - Flip `var.landing_prod_enabled = true` em `infra/envs/prod/terraform.tfvars`.
        - Atualizar registros DNS de prod no Terraform (apex A/AAAA → site prod da landing; redirect www).
        - Atualizar CTAs da landing AS IS de `app.homolog.turni.com.br` para `app.turni.com.br` (mecânica conforme ADR-012 — placeholder build-time ou PR manual).
        - Atualizar `apps/landing/public/<path-secreto>/index.html` removendo `<meta name="robots" content="noindex,nofollow">` (path-secreto vai virar apex em breve).
        - Atualizar `robots.txt` removendo `Disallow: /<path-secreto>/` (será irrelevante após swap).
     b. **Após revisão:** PR aprovado; merge.
     c. **T-1h:** `terraform plan` em prod revisado; `terraform apply` (cria site `turni-landing-prod`, registra domínios).
     d. **T-0:** tag `landing-vX.Y.Z` (sem `-rc`) → workflow dispara → gate humano em GitHub Environment `landing-prod` → 1 clique de aprovação → deploy. Smoke test em `https://turni.com.br/` retorna landing (não mais "Em breve"); `https://www.turni.com.br/` retorna 301 para apex; `https://turni.com.br/<path-secreto>/` retorna landing (mesmo conteúdo, agora **também** disponível no apex).
     e. **T+0:** comunicação comercial → marketing/parceiros que a landing está pública.
     f. **Destino do path antigo (PDR-015 §7):** PR de seguimento configura **301 do `<path-secreto>` para `/` por 90 dias**; após 90 dias, trocar por **410 Gone**. Os 90 dias preservam links já compartilhados com parceiros/imprensa; o 410 aposenta formalmente o path.
   - Quem executa: engenharia (todos os passos técnicos); comercial (autorização e comunicação T+0).
   - SLA: janela mínima de **24h** entre autorização e go-public (PDR-015 §7), condicionada ao WebApp prod já estar no ar.

7. **Procedimento P7 — Verificações de saúde periódicas.**
   - Pré-condição: nenhuma; checklist semanal de engenharia.
   - Passos:
     a. `curl -sI https://landing.homolog.turni.com.br/` → 200.
     b. `curl -sI https://landing.homolog.turni.com.br/<path-secreto>/` → 200.
     c. `curl -s https://landing.homolog.turni.com.br/robots.txt | grep Disallow` → presente.
     d. Lighthouse mobile rodado: Performance ≥ 70 (landing) / ≥ 90 (Em breve).
     e. Verificar último deploy no Firebase Hosting; data + autor.
     f. Verificar GitHub Environment `landing-prod` — revisor ainda configurado.
     g. Quando prod estiver no ar, repetir a-e para `turni.com.br`.
   - Quem executa: engenharia (rotação on-call).
   - SLA: semanal.

## Por quê (valor para o usuário)

Indireto, mas crítico: transforma operações de **risco moderado** (rollback sob pressão, rotação após vazamento, go-public coordenado) em **runbooks de minutos**. Sem o runbook, cada uma dessas operações vira improviso e o time descobre na hora errada que faltou um passo.

## Critérios de aceite

- [x] **CA-1:** `docs/operacao/runbook-landing.md` existe, no formato dos runbooks existentes (espelhar `docs/operacao/runbook-homolog.md`). Cabeçalho + Índice + procedimentos numerados + apêndice, como no `runbook-homolog.md`.
- [x] **CA-2:** Cada um dos 7 procedimentos (P1-P7) tem: título, pré-condições, passos numerados executáveis (com comandos exatos onde aplicável), verificações pós-execução, quem pode executar, SLA quando aplicável.
- [x] **CA-3:** Comandos exatos do Firebase CLI, gcloud, terraform, gh CLI estão presentes onde aplicável — copia-cola executável (REST do Firebase Hosting, `gh secret set`, `terraform plan/apply`, `git tag`, `dig`/`curl`).
- [x] **CA-4:** Referências cruzadas: cada procedimento aponta para ADR-012/PDR-015/STORY relevante quando aplicável.
- [x] **CA-5:** Runbook **não vaza** o path real — usa placeholder `<path-secreto>` literal. Verificado: o valor real nunca foi acessado nesta sessão e o repo só contém `_lp/`. `grep -rn "Disallow: /" docs/operacao/runbook-landing.md` só casa placeholders.
- [x] **CA-6:** Procedimento P6 (go-public) **chancelado pelo Alexandro (PO)** em chat (2026-05-29): passo-a-passo aprovado; decisão de **NÃO ir para prod / NÃO publicar por ora** — estado atual (gate em homolog, `landing_prod_enabled=false`) está OK.
- [x] **CA-7:** P2 (rollback) exercitado em homolog via REST — output anexado em "Notas". Estado restaurado.
- [x] **CA-8:** Link do runbook adicionado ao `apps/landing/README.md` (agora link markdown clicável).
- [x] **CA-9:** Aprovado pelo PO em chat (2026-05-29); commit direto na `main` (feedback-git-workflow — time solo, sem PR formal).

## Fora de escopo

- Implementar qualquer dos procedimentos (rotação real, go-public real, etc.) — runbook apenas documenta.
- Decidir o valor concreto do `<path-secreto>` — comercial define.
- Monitoramento contínuo/alertas — fora; P7 cobre checklist semanal manual.
- Treinar marketing/comercial em como executar — fora do escopo de engenharia; PDR-015 acomoda comunicação.
- Estender runbook para incidentes não previstos (DDoS, comprometimento do GCP) — fora; runbook futuro de incidentes cobre.

## Padrões de qualidade exigidos

- **Documentação executável:** comandos exatos, copia-cola; ninguém deve precisar adivinhar.
- **Sem vazamento:** placeholder do path secreto, sem credenciais inline.
- **Verificação:** pelo menos um procedimento exercitado (P2 é o mais natural).
- **Versionamento:** runbook é markdown no monorepo; mudanças via PR; histórico no git.

## Dependências

- **Bloqueada por:** STORY-027 (PDR-015 fixa protocolos), STORY-029 (Terraform de prod com `landing_prod_enabled`), STORY-030 (apps/landing/ estruturado), STORY-031 (workflow + comandos a documentar).
- **Bloqueia:** STORY-033 (validador verifica que runbook existe e cobre os procedimentos).

## Decisões já tomadas (não as reabra)

- **ADR-012** — mecânica do gate, swap CTA, sw.js.
- **PDR-015** — fronteira de responsabilidade, SLA, protocolo de go-public, rotação.
- **ADR-004** — gate humano em prod via GitHub Environments.

## Liberdade técnica do agente

Você (programador) decide:
- Estrutura concreta do runbook (1 arquivo único vs. múltiplos? — recomendação: 1 arquivo com TOC; reflexão à `runbook-homolog.md`).
- Formato dos comandos (bash code blocks vs. listas) — bash code blocks são padrão.
- Nível de detalhe de cada procedimento (quanto mais "novato no time" pode seguir, melhor).
- Qual procedimento exercitar para CA-7 (recomendação P2).

Você (programador) NÃO decide:
- Adicionar procedimentos de execução de rotação/go-public sem coordenar (runbook documenta; não executa).
- Vazar valor real do `<path-secreto>` no runbook commitado.
- Pular CA-7 (exercitar pelo menos um procedimento).

## Definição de Pronto (DoD)

- [ ] Todos os CAs (CA-1 a CA-9) passam.
- [ ] Exercício do P2 (ou alternativo) anexado em "Notas".
- [ ] `apps/landing/README.md` linka para o runbook.
- [ ] `index.json` atualizado: `in_review` ao abrir PR; `done` após merge.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/programador/SKILL.md`. Resumo:

1. Frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. Confirme dependências `done`.
3. Redija o runbook lendo workflow + Terraform + ADR-012 + PDR-015.
4. Exercite P2 (rollback) em homolog para validar comandos; anexe output.
5. Abra PR; aguarde revisão do PO; mergeie.
6. Atualize `index.json`. Marque `status: done`.

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
- **Documentos lidos:** esta estória inteira; `runbook-homolog.md` (formato precedente);
  `SKILL.md` do programador; ADR-012 (9 decisões do gate); PDR-015 (8 dimensões de
  processo); `firebase.json` (5 targets, incl. landing-homolog/prod/www-redirect);
  `.firebaserc`; `.github/workflows/landing-deploy.yml`; `apps/landing/README.md`;
  `infra/envs/prod/main.tf` + `variables.tf` (`landing_prod_enabled`, `dns_landing`);
  `apps/landing/public/robots.txt`; entrada da STORY-032 no `index.json`.
- **Entendimento consolidado:** estória de **redação de documentação** — nada novo é
  decidido; o runbook escreve *como* executar os 7 procedimentos que ADR-012 e PDR-015
  já decidiram *o quê/quem*. Não toca código de produção.
- **Dúvidas:** nenhuma bloqueante. Resolvi divergências lendo a implementação real (ver
  Descobertas) em vez de adivinhar.
- **Plano:** (1) ler tudo; (2) exercitar P2 contra homolog real para validar comandos;
  (3) redigir o runbook com comandos copia-cola; (4) linkar no README; (5) marcar CAs.

### Decisões tomadas
- **Documentar o nome de secret REAL** (`LANDING_SECRET_PATH`) como autoritativo, não o
  de design (`FIREBASE_LANDING_PATH`). O runbook serve para operar — tem de bater com o
  que o pipeline lê. Divergência registrada no apêndice.
- **P2 via REST** como caminho recomendado (não `firebase hosting:rollback`, que não
  existe) — é exatamente o que o auto-rollback do pipeline faz, logo o mais exercitado.
  Documentei também Console e `hosting:clone` como alternativas.
- **Corrigi os passos da própria estória** quando a implementação os tornou obsoletos
  (rotação **não** usa `git mv`; `robots.txt` é template) — registrado no apêndice em
  vez de copiar passos que dariam erro a quem seguir.
- **Arquivo único com TOC** (recomendação da estória), espelhando `runbook-homolog.md`.

### Descobertas
1. **`firebase hosting:rollback` não existe** (firebase-tools 13.x e 15.15.0 testadas).
   Confere com a descoberta já anotada no `index.json` (STORY-031). Rollback real =
   REST / Console / `hosting:clone`.
2. **Nome do secret:** workflow usa `LANDING_SECRET_PATH`; ADR-012/README/robots citam
   `FIREBASE_LANDING_PATH`. Autoritativo p/ operar = `LANDING_SECRET_PATH`.
3. **Rotação de path** não envolve `git mv` nem edição de `robots.txt`/Terraform — só
   trocar o secret + redeploy via tag. Mais simples que a estória previa.
4. Pendência menor herdada: o `runbook-homolog.md` ainda cita `firebase hosting:rollback`
   para o webapp — anotado no apêndice para corrigir em passe futuro (fora do escopo desta estória).

### Bloqueios encontrados
Nenhum bloqueio técnico. CA-6 (chancela do P6 pelo PO) e CA-9 (aprovação) são gates
humanos pendentes — não bloqueiam a redação.

### Exercício de procedimento
- **P escolhido:** P2 (rollback emergencial) — recomendado pela estória; baixo risco.
- **Comandos executados:** REST do Firebase Hosting contra `turni-landing-homolog` —
  listar releases, `POST .../releases?versionName=...` para re-release da versão anterior
  (rc.3) e depois restaurar a original (rc.4).
- **Output:**
  ```
  inicial: live = rc.4 (669a15851b894c1d), apex / → 200 "Em breve"
  rollback → type=ROLLBACK version=.../4763dbf1246e681e (rc.3) @15:48:50Z; apex → 200 ✅
  restore  → type=ROLLBACK version=.../669a15851b894c1d (rc.4) @15:49:08Z; apex → 200 ✅
  ```
- **Tempo total:** ~1 min. Homolog ficou 200 o tempo todo; estado restaurado ao original.
  (Detalhe completo no runbook, seção "Exercício de validação — P2".)

### Pendências para fechar
- Nenhuma. CA-6 chancelado e CA-9 aprovado pelo Alexandro em chat (2026-05-29).
- **Decisão do PO:** **não** ir para prod nem publicar por ora — o estado atual (gate em
  homolog, `landing_prod_enabled=false`) está OK. P6 (go-public) fica documentado e
  pronto para quando o comercial autorizar.

### Links de evidência
- Runbook: `docs/operacao/runbook-landing.md`.
- Link no README: `apps/landing/README.md`.
- Exercício P2: releases ROLLBACK de 2026-05-29T15:48–15:49Z no site `turni-landing-homolog`.
- Commit/PR: (a preencher após commit).
