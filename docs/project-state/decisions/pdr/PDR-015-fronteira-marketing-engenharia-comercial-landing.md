---
pdr_id: PDR-015
slug: fronteira-marketing-engenharia-comercial-landing
title: Fronteira de responsabilidade marketing × engenharia × comercial na landing institucional
status: accepted
decided_at: 2026-05-28
decided_by: PO (Alexandro / Claude)
approved_by: Alexandro
supersedes: null
superseded_by: null
related_epics: [EPIC-006]
related_adrs: [ADR-004, ADR-012]
related_pdrs: [PDR-003, PDR-011, PDR-012]
---

# PDR-015 — Fronteira de responsabilidade marketing × engenharia × comercial na landing institucional

## Contexto

O EPIC-006 sobe a landing institucional em `turni.com.br` com três stakeholders de responsabilidades distintas e potencialmente conflitantes: o **marketing** é dono do conteúdo da landing AS IS (HTML/CSS/JS/copy/imagens); a **engenharia** mantém a página "Em breve", a infra de routing, o pipeline e o gate; o **comercial** decide quando a landing pode ser exposta publicamente (go-public). A ADR-012 já fixou a **mecânica técnica** do gate (site único com rotas explícitas, path injetado em build-time, 404 institucional, política de cache, CODEOWNERS por placeholder estável). Falta o **acordo de processo** por trás dessa mecânica: quem aceita mudanças em cada path, em quanto tempo a engenharia responde quando algo quebra, como o `<path-secreto>` é rotacionado se vazar e — principalmente — qual o **protocolo de go-public**, o momento de maior risco do épico (a landing deixa de estar atrás do gate e vira o apex, sob pressão de calendário de campanha do comercial).

Sem este acordo escrito, três falhas previsíveis acontecem: (1) marketing pede deploy às 23h de sexta sem SLA combinado e cobra resposta que ninguém prometeu; (2) engenharia "conserta" o HTML do marketing e quebra a fronteira AS IS; (3) comercial promove a landing para o apex sem combinar o procedimento técnico com a engenharia, gerando incidente no pior momento possível. O `CODEOWNERS` (ADR-012 §9, materializado na STORY-030) é o mecanismo técnico — quem precisa aprovar PR em cada path; **PDR-015 é o contrato de execução por trás dele**. Sem PDR-015, o `CODEOWNERS` é sintaxe sem acordo.

Este é registro **leve** (decisão de produto/processo, não decisão arquitetural). Cobre o caminho feliz e os desvios críticos (path vaza, marketing quebra a landing, comercial quer go-public); não pretende esgotar exceções. **Realidade do time:** o Turni opera com uma pessoa nos cinco papéis. Os acordos abaixo são calibrados para essa realidade — SLAs honestos (best-effort em vez de número que ninguém pode cumprir sozinho), não compromissos teatrais que viram dívida no primeiro incidente.

## Opções consideradas

### Opção 1 — Sem acordo escrito (status quo)
- Descrição: a fronteira vive só em conversa; `CODEOWNERS` define aprovação técnica e o resto é improviso.
- Prós: zero esforço de redação.
- Contras: o go-public — momento de maior risco — vira improviso sob pressão; SLAs implícitos geram cobrança sobre promessas que ninguém fez; engenharia pode cruzar a fronteira AS IS sem registro.

### Opção 2 — Acordo de processo escrito e aceito, calibrado para time de 1 (ESCOLHIDA)
- Descrição: PDR-015 fixa, por dimensão, quem decide o quê, com SLAs realistas para time solo, protocolo de go-public com janela e handoff, e protocolo de rotação de path. O PO/CEO chancela em nome dos três papéis.
- Prós: transforma o go-public de improviso em runbook de minutos (materializado na STORY-032); alinha expectativas de SLA com honestidade; protege a fronteira AS IS; dá ao `CODEOWNERS` o contrato que ele pressupõe.
- Contras: exige manter o acordo vivo se a fronteira mudar (revisão via PDR superveniente).

### Opção 3 — Acordo com SLAs rígidos e numéricos
- Descrição: como a Opção 2, mas com SLA de rollback de 30 min / 2h e rotação de path em ≤ 24h, ao estilo de um time com on-call.
- Contras: o Turni não tem on-call; prometer 30 min fora de hora é compromisso que a primeira falha noturna descumpre, corroendo a confiança no próprio acordo. Número teatral é pior que best-effort honesto.

## Decisão

> **Optamos pela Opção 2.**

A fronteira de responsabilidade da landing institucional fica fixada nas **oito dimensões** abaixo. Os papéis são **marketing** (conteúdo da landing AS IS), **engenharia** (página "Em breve", gate, infra, pipeline) e **comercial** (decisão de go-public e de exposição do path). Onde o épico (`epic.md`) e a ADR-012 já fixaram algo, PDR-015 herda e não reabre.

### §1 — Propriedade do conteúdo da landing AS IS (`apps/landing/public/_lp/**`)

**O marketing é dono.** Pode editar HTML/CSS/JS/copy/imagens da landing sem revisão técnica de engenharia — o `CODEOWNERS` (ADR-012 §9) exige aprovação **apenas** do marketing (`@turni/marketing`) nesse path. (O path real fica injetado em build-time; o repositório usa a pasta-placeholder estável `_lp/`, conforme ADR-012 §2.)

**A engenharia não modifica o conteúdo da landing AS IS**, com duas exceções declaradas:
1. As **quatro adaptações mecânicas** da importação inicial (epic.md): troca de CTAs `app.html#/...` por placeholder `__WEBAPP_URL__`, remoção de `app.html` e assets exclusivos do protótipo do WebApp, injeção de `<meta name="robots" content="noindex,nofollow">`, e headers de cache/segurança no `firebase.json`. Executadas **uma vez** na STORY-030 e nunca mais.
2. **Remediação emergencial documentada** (ver §4): se um push do marketing derrubar a landing ou criar risco de leak, a engenharia pode reverter (rollback) ou remover o `sw.js` (ADR-012 §5) — sem reescrever o conteúdo, apenas restaurando o último estado bom. Toda intervenção emergencial é registrada (commit + nota no runbook).

### §2 — Propriedade da página "Em breve" (`apps/landing/public/index.html`)

**A engenharia é dona.** A página "Em breve" é artefato novo (não AS IS), de ciclo de vida próprio. O marketing **pode pedir ajuste de copy via PR**; a engenharia revisa e mergeia (CODEOWNERS direciona esse arquivo para `@turni/engenharia`). Mudanças visuais maiores (logo nova, mudança de palette) seguem o mesmo fluxo, com input do Design System (DDR-001) — a "Em breve" reaproveita os tokens visuais da landing e deve permanecer coerente com o DS.

### §3 — Propriedade da infra (`firebase.json`, `.firebaserc`, `404.html`, `robots.txt`, workflow de deploy, Terraform)

**A engenharia é dona exclusiva.** O marketing não revisa nem aprova esses arquivos. O `robots.txt` é template (path injetado no build, ADR-012 §2) — pertence à engenharia. Mecânica de gate, política de 404, cache e `sw.js` são da engenharia/arquiteto (ADR-012), fora do alcance de marketing e comercial.

### §4 — SLA de resposta da engenharia se o marketing quebrar a landing

**Best-effort, sem SLA numérico.** O Turni opera com uma pessoa nos cinco papéis; não há on-call. A engenharia responde a uma landing quebrada **assim que possível**, priorizando sobre trabalho não-urgente, sem comprometer um número fixo de minutos que o time solo não pode honrar de forma confiável. Em contrapartida, o **risco é estruturalmente baixo**: deploy isolado (ADR-012, não derruba WebApp/API/Admin), rollback é operação de um comando (`firebase hosting:rollback`, runbook STORY-032 P2), e a "Em breve" no apex — o que o público vê por padrão — não depende do conteúdo AS IS que o marketing edita.

- **Quem dispara o rollback:** o engenheiro (Alexandro no papel de engenharia) ou qualquer pessoa com acesso ao Firebase Hosting CLI seguindo o runbook (STORY-032).
- **Como o marketing comunica o problema:** pelo canal combinado do time (ver §7 — mesmo canal do go-public). A comunicação informa o quê quebrou e a gravidade percebida (apex fora do ar ≠ um asset torto numa seção interna).
- **Honestidade declarada:** "best-effort" significa que a landing AS IS pode ficar quebrada por horas se o incidente cair fora de uma janela de trabalho. Aceito explicitamente — a alternativa (número teatral) é pior. Quando o time crescer e houver on-call real, este parágrafo é o primeiro a ser revisado (sinal de revisão abaixo).

### §5 — Cadência e janela de release da landing

**Push sob demanda, sem on-call fora do horário de trabalho.** O marketing pode dar push (abrir tag de release da landing) a **qualquer momento** — o pipeline é tag-based e isolado (ADR-004/ADR-012). A engenharia **não promete acompanhar** deploys fora do horário de trabalho. Diretriz simples para mudanças grandes (redesign, troca de muitos assets): **evitar push depois das 17h de sexta sem combinar antes**, para não deixar uma landing potencialmente quebrada sem ninguém de olho no fim de semana. Não é proibição — é cortesia operacional que protege o próprio marketing.

### §6 — Protocolo de rotação do `<path-secreto>` se vazar

A mecânica de rotação está na ADR-012 §2 (trocar o secret `FIREBASE_LANDING_PATH` em homolog e prod + redeploy via tag; o path antigo passa a retornar 404 institucional). PDR-015 fixa o **processo**:

- **Quem decide a rotação:** o **comercial**, em coordenação com a engenharia. O comercial é dono da lista de convidados legítimos do path e julga se um vazamento justifica rotação.
- **Gatilho:** vazamento confirmado para fora do círculo autorizado, **ou** rotação preventiva agendada pelo comercial.
- **Prazo de execução:** **sob demanda, sem prazo fixo.** Coerente com o modelo de obfuscação declarado na ADR-012 ("o path é descobrível por URL, log, referrer, Wayback e pelo próprio `robots.txt`; a garantia real de não-indexação é o `<meta noindex,nofollow>`"). Como o gate **não é segurança**, um vazamento não é incidente de segurança que exija resposta cronometrada — a rotação acontece quando o comercial pedir e a engenharia conseguir executar. Se o comercial precisar de **proteção real** com SLA de resposta, o caminho é basic-auth / IP allowlist (ampliação fora do EPIC-006), e o SLA seria redefinido junto.
- **Quem executa:** a engenharia, via runbook (STORY-032 P3).
- **Comunicação aos detentores legítimos:** o comercial recompartilha o novo path com a lista de convidados após a rotação. Engenharia não tem essa lista — ela é responsabilidade do comercial.

### §7 — Protocolo de go-public (a decisão mais importante)

Go-public é o momento em que a landing deixa de estar atrás do gate e passa a ser servida no apex (`turni.com.br/`), descartando ou redirecionando a página "Em breve". É o ponto de maior risco do épico — acontece sob calendário de campanha do comercial.

- **Quem decide:** o **comercial**, com chancela do Alexandro como CEO. Enquanto o comercial não autorizar, a "Em breve" permanece no apex (premissa do épico).
- **Como é comunicado à engenharia:** por **artefato registrado** no monorepo — uma **issue ou PR** que marca o "go-public" com **data alvo** explícita. Não vale combinar só por conversa; o go-public precisa de rastro escrito (princípio #5: estado registrado). O mesmo artefato/canal serve para a comunicação de incidentes do §4.
- **Janela mínima de aviso:** **≥ 24h** entre o aviso registrado e a data alvo. Como a ADR-012 desenhou o go-public para ser **operação de minutos** (swap de CTA via `__WEBAPP_URL__`, remoção do gate, ajuste de `robots.txt`, todos build-time), 24h dão folga suficiente para a engenharia preparar e executar **desde que o WebApp em produção já esteja no ar** (pré-condição: o swap de CTA `homolog → prod` depende do cutover de produção do WebApp, WAVE-2026-02). Se o WebApp prod ainda não existir na data do go-public, a janela de 24h não se aplica — o go-public fica bloqueado pelo cutover, não pela engenharia da landing.
- **Quem executa tecnicamente:** a **engenharia**, seguindo o runbook (STORY-032 P6): swap dos CTAs para `app.turni.com.br`, remoção/substituição da "Em breve", atualização do `robots.txt` (a landing passa a ser indexável), remoção do `<meta noindex>`, comunicação a quem linkava o path secreto.
- **Destino do `<path-secreto>` após o go-public:** **redirect 301 do path antigo para `/` por 90 dias, depois 410 Gone.** Os 90 dias preservam links que parceiros/imprensa/investidores já tinham; após esse período o path antigo é formalmente aposentado (410), sinalizando a buscadores e clientes que aquele endereço não existe mais.

### §8 — Limites do PDR (o que NÃO está coberto)

Fica explicitamente **fora** deste acordo e para decisão futura, se e quando o comercial/marketing pedir:

- **Marketing internacional / i18n** (versão em inglês ou outros idiomas da landing).
- **Captura de lead com backend próprio** na "Em breve" ou na landing ("avise-me quando lançar", newsletter). Se houver formulário, aponta para serviço externo (Typeform/Tally/`mailto:`).
- **A/B testing** de copy ou layout.
- **Analytics / GTM / Hotjar / pixel de mídia paga.**
- **Integração com CRM.**
- **Proteção real do path** (basic-auth, IP allowlist, signed URL) — o gate é obfuscação por decisão do épico; proteção real é ampliação separada que, se vier, redefine §6.

Tudo isso está fora do EPIC-006 e fora de PDR-015.

## Justificativa

A Opção 2 dá ao `CODEOWNERS` (ADR-012 §9) o contrato de execução que ele pressupõe e transforma o go-public — o maior risco do épico — de improviso sob pressão em um runbook de minutos com handoff escrito. A calibragem para time de 1 (best-effort em §4, sob-demanda em §6) é deliberada: prometer SLA numérico que uma pessoa sozinha não pode cumprir corrói a confiança no acordo no primeiro incidente — e o risco real é baixo porque a infra (ADR-012) isola o deploy, torna o rollback trivial e mantém a "Em breve" no apex independente do conteúdo AS IS. A janela de ≥ 24h para go-public (§7) aproveita que a ADR-012 desenhou a promoção como mudança de variável, não refactor; mais que isso seria cerimônia desnecessária para uma operação de minutos, e o gargalo verdadeiro do go-public é o cutover de produção do WebApp (WAVE-2026-02), não a landing.

## Consequências

### Positivas
- `CODEOWNERS` ganha o acordo de processo que o sustenta; aprovação de PR por path deixa de ser sintaxe vazia.
- Go-public vira runbook de minutos com handoff escrito (STORY-032 P6) — risco controlado no momento mais crítico.
- Expectativas de SLA alinhadas com honestidade: ninguém cobra um número que o time solo não prometeu.
- Fronteira AS IS protegida: engenharia tem regra clara do que pode (4 adaptações + remediação emergencial) e não pode tocar.
- Rastro escrito do go-public e dos incidentes (princípio #5).

### Negativas / trade-offs aceitos
- **Best-effort sem SLA numérico (§4):** a landing AS IS pode ficar quebrada por horas se o incidente cair fora de uma janela de trabalho. Aceito — risco baixo (infra isola; "Em breve" no apex não depende do AS IS).
- **Rotação de path sem prazo (§6):** coerente com "obfuscação, não segurança"; quem precisar de garantia cronometrada precisa de proteção real (ampliação fora de escopo).
- **Acordo precisa ser mantido vivo:** se a fronteira mudar (time cresce, on-call surge, comercial pede proteção real), PDR-015 é revisado por PDR superveniente (`supersedes`/`superseded_by`).
- **Chancela informal de marketing/comercial:** no time atual o PO/CEO chancela em nome dos três papéis; aprovações explícitas de leads de marketing/comercial são bem-vindas mas não bloqueantes (não há esses leads como pessoas distintas hoje).

### Para o time técnico
- **ADRs relacionadas:** ADR-012 (mecânica do gate, rotação, CODEOWNERS por placeholder) é o par técnico de PDR-015; ADR-004 (pipeline tag-based + gate humano em prod) é herdada como ponto de controle do go-public.
- **Impacto em estórias:** STORY-030 materializa a fronteira (`CODEOWNERS`, `README.md`); STORY-032 escreve o runbook que executa os protocolos (§4 rollback, §6 rotação, §7 go-public). Os números de SLA do runbook devem refletir esta PDR (best-effort em vez de 30 min; sob-demanda em vez de 24h; ≥ 24h de aviso de go-public em vez de 48h).
- **Não bloqueia** 028/029/031 — a mecânica técnica é independente da decisão de processo.

## Sinais de revisão

- **Time cresce / surge on-call real** → revisar §4 (best-effort vira SLA numérico) e §5 (passa a haver cobertura fora do horário).
- **Comercial pede proteção real do path** (vazamento incomoda de fato) → nova decisão de produto + ADR (basic-auth/IP allowlist); §6 ganha SLA de resposta.
- **Go-public se mostra mais complexo que "minutos"** na prática (ex.: dependências de SEO, migração de tráfego, coordenação com mídia paga) → ampliar a janela de §7 acima de 24h.
- **Marketing quebra a landing com frequência** (mais de 2-3 vezes) → revisar §1 (talvez um smoke-test automático pós-deploy que barra push quebrado antes de ir ao ar).
- **Conflito recorrente sobre quem aprova o quê** → o `CODEOWNERS` e/ou os aliases (`@turni/marketing`, `@turni/engenharia`) precisam de ajuste; reabrir junto com a STORY-030.

## Relação com outros PDRs e ADRs

- **Complementa ADR-012** (mecânica do gate): PDR-015 é o acordo de processo por trás da mecânica; ADR-012 §2 (rotação) e §9 (CODEOWNERS) apontam para esta PDR para o "quem decide / quem executa".
- **Herda ADR-004** (pipeline tag-based + gate humano de 1 clique em prod): o gate humano é o ponto de controle técnico do go-public (§7).
- **Honra PDR-003** (três superfícies isoladas — WebApp, Backoffice, landing): a fronteira de propriedade reforça o isolamento da terceira superfície.
- **Roda na onda de PDR-011** (WAVE-2026-01, EPIC-006 em paralelo).
- **Espelha o padrão de PDR-012** (responsabilidade de manutenção de conteúdo migra para quem é dono do domínio — lá os templates contratuais para o admin; aqui o conteúdo da landing para o marketing).
