---
story_id: STORY-027
slug: pdr-fronteira-marketing-engenharia-comercial
title: PO — PDR-015 Fronteira de responsabilidade marketing × engenharia × comercial na landing
epic_id: EPIC-006
sprint_id: SPRINT-2026-W24-LANDING
type: decision
target_role: po
requires_design: false
status: done
owner_agent: claude-opus-po-2026-05-28
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: S
---

# STORY-027 — PDR-015: fronteira de responsabilidade na landing (marketing × engenharia × comercial)

> **Para o agente que vai executar:** leia esta estória por inteiro antes de começar. Ela contém tudo o que você precisa. Se algo estiver ambíguo, registre a dúvida na seção "Notas do agente" no final e pause em vez de adivinhar.

## Contexto (por que esta estória existe)

A landing institucional tem três stakeholders com responsabilidades distintas e potencialmente conflitantes: o **marketing** é dono do conteúdo (HTML/CSS/JS/copy/imagens da landing AS IS); a **engenharia** mantém a página "Em breve", a infra de routing, o pipeline e o gate; o **comercial** decide quando a landing pode ser exposta publicamente (go-public). Sem um acordo escrito sobre quem decide o quê, três coisas ruins acontecem: (1) marketing pode pedir um deploy às 23h de sexta sem combinar SLA; (2) engenharia pode "consertar" o HTML do marketing e quebrar a fronteira; (3) comercial pode promover a landing para o apex sem combinar com engenharia o procedimento técnico, gerando incidente.

`CODEOWNERS` (decidido em ADR-012) é o mecanismo técnico — quem precisa aprovar PR em cada path. PDR-015 é o **acordo de processo por trás do CODEOWNERS**: quem aceita mudanças, em quanto tempo, o que fazer quando dá errado, como rotacionar o `<path-secreto>` se vazar, e — principalmente — o protocolo de **go-public** (o momento em que a landing deixa de estar atrás do gate e vira o apex).

PDR-015 é registro **leve** (decisão de produto/processo, não decisão arquitetural). O esforço é alinhar com os stakeholders (Alexandro como PO/CEO conversa com marketing e comercial) e escrever o acordo num parágrafo por dimensão. Não precisa cobrir cenários de exceção exaustivos — só o caminho feliz e os 2-3 desvios mais críticos (path vaza, marketing quebra a landing, comercial quer go-public).

- Épico: `docs/project-state/epics/EPIC-006-landing-institucional/epic.md`
- Documentos canônicos a ler ANTES de redigir:
  - `epic.md` do EPIC-006 (seção "Decisões de produto necessárias" lista as perguntas que PDR-015 responde)
  - `docs/project-state/decisions/pdr/PDR-003-duas-interfaces-webapp-e-backoffice.md` (precedente de PDR que fixa fronteira entre interfaces)
  - `docs/project-state/decisions/pdr/PDR-011-escopo-da-wave-2026-01.md` (formato de PDR de processo/escopo)
  - `docs/project-state/decisions/pdr/PDR-012-templates-contratuais-editaveis-no-backoffice.md` (precedente de PDR que fixa responsabilidade de manutenção)
  - `docs/skills/po/SKILL.md` e `docs/skills/po/references/quality-standards.md`

## O quê (objetivo desta estória)

Redigir e aprovar **PDR-015 — Fronteira de responsabilidade marketing × engenharia × comercial na landing institucional**, em estado `accepted`, cobrindo:

1. **Propriedade do conteúdo da landing AS IS** (`apps/landing/public/<path-secreto>/**`). Marketing é dono. Pode editar HTML/CSS/JS/copy/imagens sem revisão técnica de engenharia — `CODEOWNERS` só exige aprovação de marketing nesse path. Engenharia não modifica esse conteúdo, exceto nas 4 adaptações mínimas da importação inicial (CTAs, exclusão de `app.html`, meta robots noindex, headers) e em remediação emergencial documentada (ver §4 abaixo).

2. **Propriedade da página "Em breve"** (`apps/landing/public/index.html`). Engenharia é dona. Marketing pode pedir ajuste de copy via PR; engenharia revisa e mergeia. Mudanças visuais maiores (logo nova, mudança de palette) seguem o mesmo fluxo, mas com input do Design System (DDR-001).

3. **Propriedade da infra** (`firebase.json`, `.firebaserc`, `404.html`, `robots.txt`, workflow de deploy, Terraform). Engenharia é dona exclusiva. Marketing não revisa nem aprova.

4. **SLA de resposta da engenharia se marketing quebrar a landing.** Acordar: tempo máximo até rollback (sugestão: 30 min em horário comercial, 2h fora). Quem dispara o rollback (engenheiro on-call ou qualquer pessoa com acesso ao Firebase Hosting CLI seguindo runbook). Como marketing comunica o problema (qual canal, qual gravidade).

5. **Cadência e janela de release da landing.** Sob demanda em horário comercial vs. janela fixa. Acordar uma diretriz simples — sugestão: marketing pode dar push a qualquer momento; engenharia não promete on-call fora do horário comercial. Janela específica para mudanças grandes (ex: "evitar push depois das 17h sexta sem combinar").

6. **Protocolo de rotação do `<path-secreto>` se vazar.** Quem decide rotação (comercial, em coordenação com engenharia). Em quanto tempo (sugestão: ≤ 24h se vazamento confirmado para fora do círculo autorizado). Procedimento técnico (engenharia executa via runbook — STORY-032). Comunicação aos detentores legítimos do path antigo.

7. **Protocolo de go-public.** Esta é a decisão mais importante de PDR-015. Acordar:
   - Quem **decide** (comercial, com chancela do Alexandro como CEO).
   - Como esse decisão é comunicada à engenharia (qual canal, qual artefato — sugestão: issue ou PR no monorepo que marca o "go-public" com data alvo).
   - Janela de aviso mínima (sugestão: ≥ 48h, para engenharia preparar swap de CTAs `homolog → prod`, remover gate, atualizar robots.txt, comunicar a outras superfícies que linkavam o path secreto).
   - Quem **executa** tecnicamente (engenharia, seguindo runbook que STORY-032 documenta).
   - O que acontece com o `<path-secreto>` após go-public (sugestão: redirect 301 do path antigo para `/` por 90 dias, depois 410 Gone).

8. **Limites do PDR.** Declarar o que **não** está coberto e fica para acordo futuro: marketing internacional (i18n), captura de lead com backend próprio, A/B testing, analytics, integração com CRM. Tudo isso fora do EPIC-006.

PDR-015 é aprovado por Alexandro (PO/CEO) e — idealmente, mas não bloqueante — chancelado pelo lead do marketing e pelo lead do comercial via comentário no PR ou mensagem registrada anexa ao PDR.

## Por quê (valor para o usuário)

Valor é interno ao time. Sem PDR-015, o `CODEOWNERS` definido em ADR-012/STORY-031 é só sintaxe sem contrato de execução. Pior: o **go-public** — o momento de maior risco do épico (landing sai do gate, comercial precisa que apareça no apex no horário combinado da campanha) — vira improviso sob pressão se não tiver protocolo escrito. PDR-015 transforma um momento de risco em um runbook de minutos.

## Critérios de aceite

- [ ] **CA-1:** Existe `docs/project-state/decisions/pdr/PDR-015-fronteira-marketing-engenharia-comercial-landing.md` em `status: accepted`, escrito conforme `docs/skills/po/templates/pdr.md` (ou estrutura dos PDRs existentes — PDR-003, PDR-011, PDR-012 como referência).
- [ ] **CA-2:** PDR-015 cobre cada uma das 8 dimensões listadas em "O quê" com **acordo concreto** (não "será definido depois") — exceto a §8 que explicitamente lista o que fica fora.
- [ ] **CA-3:** PDR-015 declara explicitamente os papéis (marketing, engenharia, comercial) e o que cada um pode/não pode fazer em cada path da estrutura `apps/landing/`.
- [ ] **CA-4:** PDR-015 define o protocolo de go-public com: quem decide, como comunica, janela mínima, quem executa, destino do path antigo após go-public.
- [ ] **CA-5:** PDR-015 define o protocolo de rotação do `<path-secreto>` com gatilhos, tempo, executor, comunicação.
- [ ] **CA-6:** PDR-015 é **aceita por Alexandro** (frontmatter `status: accepted`, `approved_by: Alexandro`, `decided_at` preenchido). Aprovações adicionais (marketing/comercial) são bem-vindas mas não bloqueantes — o PO/CEO chancela em nome dos três.
- [ ] **CA-7:** `index.json` reflete: PDR-015 com `status: accepted` no array de decisions; esta estória (STORY-027) com `status: done`.
- [ ] **CA-8:** Referências cruzadas: o `epic.md` do EPIC-006 já aponta para PDR-015 (e foi atualizado em ajuste anterior — confirme); a STORY-030 que toca `CODEOWNERS` referencia PDR-015 nas decisões já tomadas; a STORY-032 que escreve o runbook referencia PDR-015 nos protocolos.

## Fora de escopo

- Implementar `CODEOWNERS` — STORY-030.
- Escrever o runbook que materializa os protocolos — STORY-032.
- Definir o valor concreto inicial do `<path-secreto>` — comercial define, fora de PDR-015.
- Definir copy da página "Em breve" — STORY-028 com input do comercial.
- Decisões arquiteturais (mecânica do gate, política de 404, cache, sw.js) — ADR-012 / STORY-026.
- Internacionalização, captura de lead, A/B testing, analytics, CRM — fora do EPIC-006.

## Padrões de qualidade exigidos

- **Decisões registradas (princípio #5):** PDR-015 é o registro escrito do acordo — sem ele, a fronteira só vive em conversa.
- **Reversibilidade:** PDR-015 pode ser revisado por PDR superveniente se a fronteira não funcionar na prática. Registrar revisões via `supersedes`/`superseded_by` quando aplicável.
- **Comunicação ao time:** após aprovação, mencionar PDR-015 no próximo update geral (Slack/email) para garantir que marketing e comercial sabem que o acordo existe.

## Dependências

- **Bloqueada por:** nada bloqueante. Pode rodar em paralelo com STORY-026.
- **Bloqueia:** STORY-030 (CODEOWNERS materializa PDR-015), STORY-032 (runbook materializa protocolos). Não bloqueia 028/029/031 — mecânica técnica é independente da decisão de processo.

## Decisões já tomadas (não as reabra)

- **epic.md do EPIC-006** — fronteira de alto nível: marketing dono do conteúdo AS IS dentro de `<path-secreto>/`; engenharia dona da "Em breve" e infra; comercial decide go-public.
- **PDR-003** — segregação entre superfícies (WebApp/Backoffice/landing).
- **ADR-004** — pipeline tag-based + gate humano em prod (PDR-015 herda o gate humano como ponto de controle do go-public).
- **PDR-011** — escopo da WAVE-2026-01.
- **Princípio do PO** — qualidade não é negociada por velocidade (PDR-015 não vai apertar SLA da engenharia abaixo do razoável só para acelerar marketing).

## Liberdade técnica do agente

Você (PO) decide:
- Texto exato de cada acordo (linguagem clara, sem juridiquês).
- Estrutura do PDR (seguir template oficial; espelhar estrutura de PDR-003/PDR-012).
- Se algum acordo precisa de exemplo (ex.: "exemplo de comunicação de path vazado").
- Como capturar a chancela informal de marketing/comercial (comentário no PR, link para mensagem registrada).

Você (PO) NÃO decide:
- Reabrir o epic.md do EPIC-006 ou ADR-012.
- Decidir mecânica técnica do gate (responsabilidade do arquiteto, ADR-012).
- Mudar fronteira de "marketing dono do conteúdo AS IS" para "marketing pede e engenharia executa" (epic.md fixa).

## Definição de Pronto (DoD)

- [ ] Todos os CAs (CA-1 a CA-8) passam.
- [ ] PDR-015 mergeada no `main` com `status: accepted` e `approved_by: Alexandro`.
- [ ] `index.json` atualizado.
- [ ] "Notas do agente" preenchida.

## Protocolo do agente (obrigatório)

Siga `docs/skills/po/SKILL.md`. Resumo:

1. Frontmatter desta estória: `status: in_progress`, `owner_agent`, `updated_at`. Atualize `index.json`.
2. Leia documentos canônicos. Conversa com Alexandro sobre os 8 acordos (idealmente sondando marketing e comercial antes da redação final).
3. Escreva PDR-015 em `status: proposed`. Abra PR.
4. Aprovação do Alexandro; ajuste se pedido; mergeie com `status: accepted`.
5. Atualize `index.json` (PDR-015 e esta estória) e marque `status: done`. Preencha "Notas".

## Notas do agente (preenchido durante/após execução)

### Entrada inicial
- Lidos: `epic.md` do EPIC-006, ADR-012 (par técnico já `accepted`), PDR-003, PDR-011, PDR-012 (precedentes), `templates/pdr.md`, `SKILL.md` do PO, `references/indexing.md`, e as estórias 030/032 (consumidoras do PDR).
- Constatação: a ADR-012 já fixou a mecânica do gate, rotação, 404, cache, sw.js e o padrão de CODEOWNERS por placeholder `_lp/`. PDR-015 não reabre nada disso — fixa só o **acordo de processo** por trás (quem decide, SLA, janelas, go-public).
- As 8 dimensões da estória traziam sugestões de default; 4 delas são compromissos reais que exigiam chancela do Alexandro como PO/CEO.

### Conversas com stakeholders
- Canal: chat da sessão (2026-05-28). No time atual o Alexandro acumula PO/CEO/marketing/engenharia/comercial; ele chancela em nome dos três papéis (CA-6).
- 4 parâmetros submetidos via questionário, com a sugestão da estória como recomendada. Alexandro **divergiu da sugestão em 3 dos 4** — escolhas mais honestas para time de 1 pessoa:
  - **SLA de rollback (§4):** escolheu **best-effort, sem número fixo** (sugestão era 30 min/2h). Razão: não há on-call; número teatral vira dívida no 1º incidente; risco real é baixo (infra isola, "Em breve" no apex independe do AS IS).
  - **Janela de go-public (§7):** escolheu **≥ 24h** (sugestão era ≥ 48h). Razão: ADR-012 fez do go-public operação de minutos; o gargalo real é o cutover de produção do WebApp (WAVE-2026-02), não a landing.
  - **Rotação de path (§6):** escolheu **sob demanda, sem prazo fixo** (sugestão era ≤ 24h). Razão: o gate é obfuscação, não segurança — vazamento não é incidente cronometrado.
  - **Destino do path pós go-public (§7):** **manteve a sugestão** — 301 → `/` por 90 dias, depois 410 Gone.

### Decisões tomadas
- **§1 Conteúdo AS IS (`_lp/**`):** marketing é dono; edita sem revisão de engenharia (CODEOWNERS → `@turni/marketing`). Engenharia só toca nas 4 adaptações da importação + remediação emergencial documentada.
- **§2 "Em breve" (`index.html`):** engenharia dona; marketing pede ajuste de copy via PR; mudanças visuais maiores com input do DDR-001.
- **§3 Infra:** engenharia exclusiva; marketing não revisa.
- **§4 SLA de quebra:** best-effort, sem número fixo (time solo; risco baixo).
- **§5 Cadência de release:** push sob demanda; sem on-call fora do horário; evitar push grande depois de sexta 17h sem combinar.
- **§6 Rotação de path:** comercial decide (dono da lista de convidados); sob demanda, sem prazo; engenharia executa via runbook (STORY-032).
- **§7 Go-public:** comercial decide + chancela CEO; comunicado por issue/PR registrado com data alvo; janela ≥ 24h (condicionada ao WebApp prod no ar); engenharia executa; path antigo → 301 p/ `/` por 90d, depois 410.
- **§8 Fora de escopo:** i18n, captura de lead com backend, A/B, analytics/GTM, CRM, proteção real do path.

### Bloqueios encontrados
- Nenhum bloqueio. ADR-012 já `accepted` removeu a ambiguidade de mecânica.

### Pendências para fechar
- Nenhuma pendência bloqueante. Aliases `@turni/marketing` / `@turni/engenharia` são materializados na STORY-030 (CODEOWNERS) — PDR-015 fixa o padrão, não o arquivo.
- Consistência: STORY-032 (runbook, ainda `ready`) carregava os números **sugeridos** (rollback ≤30 min, rotação ≤24h, go-public ≥48h). Alinhados nesta sessão aos valores realmente decididos na PDR-015 (best-effort / sob-demanda / ≥24h + destino 301→410 do path), para não deixar contradição no estado do projeto. CA-8 confirmado: epic.md, STORY-030 e STORY-032 referenciam PDR-015.
- Comunicação ao time (padrão de qualidade): mencionar PDR-015 no próximo update geral para garantir que marketing/comercial saibam que o acordo existe.

### Links de evidência
- PDR: `docs/project-state/decisions/pdr/PDR-015-fronteira-marketing-engenharia-comercial-landing.md` (`status: accepted`, `approved_by: Alexandro`, `decided_at: 2026-05-28`).
- `index.json`: PDR-015 em `decisions.pdr[]` (`accepted`); STORY-027 `status: done` com `produces_pdr: PDR-015`.
- Workflow Turni: commit direto na `main` (sem PR), conforme preferência registrada do Alexandro.
