# Componentes

> Cada componente mapeia, sempre que possível, para um **widget Flutter Material 3** existente. Componente custom só existe quando o Flutter não cobre — e entra por DDR. O `id` é o que o spec de tela referencia em `ds_components_used`.

A versão 0.1 cobre **apenas** o necessário para o EPIC-000 (página de boas-vindas, STORY-008). A lista completa para EPIC-001 está em §Roadmap.

> **Cor dos componentes é resolvida por tema × perfil** (`tokens.md §1`). Onde abaixo se lê `primary`/`accent`/`on-accent`, vale o acento do **perfil ativo** (profissional/contratante/admin) no **tema ativo** (claro/escuro). Pré-login = esquema profissional. Componentes não fixam hex — consomem o `ColorScheme` resolvido.

---

## `brand.logo`

**Descrição:** logomarca "TURN**I**." — wordmark da marca. "TURN" + "N" em `text.strong` (ou branco sobre fundo escuro), "I" em `brand.green` `#00A868`, ponto final com contorno (`stroke`) verde.

**Flutter:** `RichText`/`Text.rich` com spans, ou `SvgPicture` quando houver asset. Fonte **Bebas Neue** (`brand.logo` é o único uso dela).

**Tamanhos:** `lg` 24–32px (header/nav), `display` ≥48px (hero/entrada).

**Acessibilidade:** envolver em `Semantics(label: 'Turni')` — o leitor de tela anuncia "Turni", não as letras soltas.

**Usar quando:** identificação de marca. **Não usar como:** título de conteúdo (use `headline`).

---

## `button.primary`

**Descrição:** ação principal de um contexto. **No máximo uma por tela.**

**Flutter:** `FilledButton` (M3); `FilledButton.icon` quando ícone à esquerda agrega.

**Anatomia:** label `label` (verbo no infinitivo + objeto) em `on-accent`; fundo `accent` (do perfil ativo); altura ≥48dp; padding horizontal `space.lg`; raio `radius.full` (pílula, padrão do protótipo).

| Estado | Comportamento |
|---|---|
| default | `accent` + `on-accent` |
| hover (web) | `accent.hover` |
| focus | anel de foco `accent` (default Material) |
| pressed | overlay 12% |
| disabled | opacidade 38% |
| loading | `CircularProgressIndicator` inline no lugar do label; toque bloqueado |

**Não usar quando:** ação secundária (`button.secondary`) ou destrutiva (`button.danger`, EPIC-001+).

---

## `link.text`

**Descrição:** navegação textual inline (ex.: link para `/health`). Sublinhado ou cor `accent.ink`, alvo de toque ≥48dp.

**Flutter:** `TextButton` com `TextStyle(color: accent.ink)`; ou `InkWell` + `Text.rich` para link inline em parágrafo.

**Anatomia:** texto `body`/`label` em `accent.ink` (texto-sobre-claro do perfil; no escuro, `accent`); ícone opcional à direita (ex.: seta externa) com `Semantics`/`tooltip`.

| Estado | Comportamento |
|---|---|
| default | texto `accent.ink` (claro) / `accent` (escuro) |
| hover (web) | sublinhado + `accent.hover` |
| focus | anel de foco visível |
| pressed | overlay sutil |

**Acessibilidade:** o texto do link descreve o destino ("Ver status do sistema"), não "clique aqui".

---

## `surface.card`

**Descrição:** container de conteúdo elevado sobre a página.

**Flutter:** `Card` (M3) ou `Container` com `surface` + `radius.lg` + `elev.1`.

**Anatomia:** fundo `surface`; raio `radius.lg`; elevação `elev.1`; padding interno `space.lg`.

---

## `badge.status`

**Descrição:** selo compacto de estado de uma entidade (Vaga, Turno) no canto do card. **Cor é
semântica, nunca de perfil**, e nunca é o único canal: rótulo textual + ícone + borda ≥3:1
(tokens §4). Nasceu como exceção na SCREEN-047; estendido com as variantes de Turno na
SCREEN-059 (registro deste uso).

**Flutter:** `Container` com `radius.full` + `Row(Icon, Text)`; borda `fg @ 40%`.

| Variante | Uso | Cor |
|---|---|---|
| success soft | vaga `aberta`, turno `confirmado` | `success.soft` + ink verde |
| success preenchido | turno `ativo` ("vivo agora") | `success` + branco |
| warning soft | turno `aguardando_checkin/checkout` | `warn.soft` + `accent.ink` mostarda |
| error soft | turno `em_disputa` | `error.soft` + ink vermelho |
| neutro | vaga `fechada`, turno `finalizado*` | cinza-quente + `text.muted` |
| error esmaecido | `cancelad*`, `no_show`, sem pagamento | rosa-acinzentado + ink esmaecido |

**Acessibilidade:** o rótulo é lido pelo leitor de tela; o ícone é decorativo (sem semantics própria).

---

## `section.group-header`

**Descrição:** cabeçalho de seção para conteúdo agrupado (overline caps, contador opcional) —
1º uso na SCREEN-059 (listas de turnos por estado); **promovido a definitivo no 2º uso**
(SCREEN-060, header "Histórico" da timeline). Seção vazia é **omitida** (sem header órfão).

**Flutter:** `Text` 12px w800 `letterSpacing 1.2` em `text.muted`, envolto em
`Semantics(header: true, label: '<Título>, N turnos')` (ou `header: true` simples sem contador).

**Anatomia:** `"{Título} ({N})"` ou `"{Título}"`; margem `space.lg` acima / `space.sm` abaixo.

---

## `timeline.event`

**Descrição:** evento de linha do tempo (dot + linha vertical + título forte + descrição
opcional muted + timestamp 24h pt-BR). 1º uso na SCREEN-060 (histórico do turno);
**promovido a definitivo no 2º uso** (SCREEN-061 — eventos `checkin_solicitado` com nota
de geofencing e `checkin_cancelado`). Ordem cronológica descendente; evento desconhecido
degrada para título genérico, nunca quebra.

**Flutter:** `Column` de linhas com `Container` para dot+linha (sem lib externa);
cada evento é um nó `Semantics` único; dot/linha decorativos (`ExcludeSemantics`).

**Anatomia:** dot 10px no acento do perfil; linha 2px `border.strong`; título 15px w700;
descrição 14px `text.muted`; timestamp 13px `text.muted` (`EEE, dd/MM · HH:mm`).

---

## Roadmap (entram por DDR/uso a partir do EPIC-001)

`button.secondary` (`OutlinedButton`), `button.danger`, `input.text` (`TextFormField`), `input.select` (`DropdownMenu`), `input.checkbox`, `input.switch`, `chip` (`FilterChip`/`InputChip`), `segmented` (`SegmentedButton`), `card.vaga`, `card.turno`, `list.tile` (`ListTile`), `snackbar`, `bottom-sheet`, `nav.bar` (`NavigationBar`) + `nav.rail` (`NavigationRail`), `app.bar`, `stepper`, `badge`. (`empty-state`→`state.empty` e `skeleton`→`state.loading` saíram do Roadmap na STORY-079.)

---

## `dialog.confirm`

**Descrição:** confirmação de uma decisão **destrutiva para o fluxo de outra pessoa** —
título-pergunta + corpo que explica a consequência + campo opcional + par
Voltar/destrutiva. 1º uso na SCREEN-062 (recusa do check-in); **promovido a definitivo
no 2º uso** (SCREEN-064 — recusa do check-out, como a 062 previu). Próximos usos
esperados: cancelamento de turno (STORY-066) e disputa (EPIC-005). Não confundir com
`dialog.document` (leitura — aceite da 060): este é DECISÃO.

**Flutter:** `AlertDialog` com `FilledButton` destrutivo em `error` sólido (branco
5.7:1) e `TextButton` "Voltar"; `showDialog<bool>` devolvendo o desfecho.

**Anatomia:** título `titleMedium` em pergunta ("Recusar check-out?"); corpo 14px
`text.muted` com a consequência explícita; campo opcional (textarea ≤280) com label;
erro inline no rodapé (o dialog NÃO fecha em erro); ações à direita (Voltar à esquerda
da destrutiva).

**Acessibilidade:** focus trap; foco inicial no corpo/título (nunca no botão
destrutivo); ESC e toque fora fecham sem efeito; botões ≥48dp; erro com
`liveRegion: true`.

**Usar quando:** a ação invalida trabalho/estado de outra parte (recusa mata o PIN do
profissional). **Não usar quando:** a ação é do próprio dono e reversível em um toque
(cancelar o próprio PIN — 061/064 — não pede confirmação) ou for só leitura
(`dialog.document`).

**Variante campo obrigatório (DDR-005).** Quando a decisão **exige** o dado para a trilha
(justificativa da disputa do contratante · nota da resolução do admin), o campo deixa de ser
opcional: `errorText` quando vazio (após blur ou tentativa de enviar), botão de confirmação
**desabilitado** até haver texto, foco inicial **no campo** (não no botão destrutivo). Mesma
anatomia do `dialog.confirm`; só muda a obrigatoriedade. 1º uso: SCREEN-091 (abrir disputa /
resolver: pagar integral).

---

## `banner.status`

**Descrição:** banner **persistente, não-dispensável e read-only** que comunica um **estado**
do recurso (não é erro recuperável, nem gate de ação). `*.soft` da cor semântica + ícone +
título + corpo — **sem CTA** (não há o que fazer; só informar). Nasce na **SCREEN-091 /
DDR-005**: "valor em disputa" no detalhe do turno do profissional em `em_disputa` (`error
soft`). Família visual do `banner.gate` (DDR-004), do qual difere por **não ter ação** e não
bloquear nada — só descrever a situação.

**Flutter:** `Container` (`*.soft` + `radius.lg` + borda na cor semântica ≥3:1) com `Row(Icon,
Column(título, corpo))`. `Semantics(liveRegion: true)` ao aparecer; ícone decorativo
(`ExcludeSemantics`) — o texto carrega o significado (cor nunca é canal único). **Não**
anunciar como clicável.

**Não confundir com:** o **banner de erro recuperável** mid-flow (com "Tentar de novo" — micro-padrão local das telas de PIN/cronômetro) nem o **`banner.gate`** (bloqueante proativo com CTA). `banner.status` é puramente informativo de estado.

---

## `button.text`

**Descrição:** ação de **baixa ênfase** no padrão "pergunta? ação" — label que combina o
contexto e o verbo (ex.: "Não chegou ainda? Cancelar PIN", "Profissional não está no
local? Recusar check-in"). 1º/2º usos na SCREEN-061 (cancelar PIN — tela do PIN e área
de ações); **promovido a definitivo no 3º uso** (SCREEN-062 — gatilho da recusa do
check-in). Não confundir com `link.text` (navegação): `button.text` executa uma AÇÃO.

**Flutter:** `TextButton` com `foregroundColor` = `accent` do perfil (claro: `accent.ink`
quando texto sobre superfície clara); `minimumSize: Size.fromHeight(48)`.

**Anatomia:** label 15px w600 em `accent.ink` (claro) / `accent` (escuro); sem borda,
sem fundo; alvo ≥48dp apesar do visual leve; loading = spinner inline no lugar do label.

| Estado | Comportamento |
|---|---|
| default | texto `accent.ink` (claro) / `accent` (escuro) |
| hover (web) | sublinhado |
| focus | anel de foco visível |
| pressed | overlay sutil |
| disabled | opacidade 38% |
| loading | spinner inline; toque bloqueado |

**Usar quando:** ação secundária de baixa ênfase ao lado de um `button.primary` (máx. 1
primário por tela — o `button.text` não compete). **Não usar quando:** for navegação
(`link.text`) ou a ação for o objetivo principal da tela (`button.primary`).

---

## `mono.display` (família "número grande em mono")

**Descrição:** dado curto de alta criticidade exibido em **JetBrains Mono grande,
centrado** — o usuário precisa ler/conferir/digitar o valor com zero ambiguidade, muitas
vezes em contexto de rua. Família registrada no **3º uso** (SCREEN-063): `pin.display`
(061 — PIN de 4 dígitos em tela cheia), `input.pin` (062 — espelho de ENTRADA do mesmo
número) e `cronometro.display` (063 — tempo vivo `HH:MM:SS`/`MM:SS` a ticar a cada 1s).

**Flutter:** `GoogleFonts.jetBrainsMono` w600; no display vivo, **`FontFeature
.tabularFigures()` é obrigatório** (o número não pode "tremer" a cada tick);
`letter-spacing` largo (0.35em) só nas variantes de PIN (dígitos isolados), nunca no
tempo (os `:` já separam).

**Variantes:** `pin.display` 56px+ (legível a 1 braço de distância); `input.pin` 28px
(32px desktop), teclado numérico, maxLength 4; `cronometro.display` 40px (48px desktop).

**Acessibilidade:** o visual mono NUNCA vaza para o leitor de tela — display vivo usa
nó `Semantics` com horas/minutos (sem segundos, sem liveRegion); input usa label
explícito ("PIN de check-in, 4 dígitos").

**Usar quando:** número curto que precisa ser conferido entre duas pessoas ou observado
em tempo real. **Não usar quando:** valor monetário em card (tipografia do tema) ou
texto corrente.

---

## `state.empty` / `state.error` / `state.loading` (estados padrão)

**Descrição:** os três estados de tela padronizados na **STORY-079** (EPIC-012),
consumidos por todas as listas do WebApp. Tiram `empty-state` e `skeleton` do Roadmap.
Detalhe de composição/uso em `patterns.md` (`pattern.empty` / `pattern.error` /
`pattern.loading`).

**Flutter:** componentes custom do DS em `apps/webapp/lib/ds/components/state_views.dart`
(o Material não cobre estado vazio/erro instrutivo nem skeleton).

| `id` | Widget | Anatomia |
|---|---|---|
| `state.empty` | `TurniEmptyState` | ícone + título + mensagem (instrui o próximo passo) + `action` (CTA) opcional. Centralizado. |
| `state.error` | `TurniRetryState` | erro **recuperável**: ícone `error_outline` + título + apoio + "Tentar de novo" que re-dispara a carga. Erro **não-recuperável** = `state.empty` com ícone de bloqueio + CTA de saída. |
| `state.loading` | `TurniSkeletonList` + `TurniSkeletonCard` + `TurniSkeletonBox` | skeleton no formato do conteúdo (card / linha com avatar), ~3×, estático. `TurniSkeletonBox` é o primitivo (barra/círculo). |

**Cor:** o CTA de `state.error`/`state.empty` é construído pela tela com o acento do
**perfil ativo** (mostarda contratante / sage profissional); `TurniRetryState` aceita
`accent` e cai em `colorScheme.primary` quando nulo.

**Acessibilidade (AA):** "erro nunca é só cor" — sempre ícone + texto; "estado vazio
sempre instrui o próximo passo". Alvo do CTA ≥48dp. O skeleton usa `ExcludeSemantics`
(não anuncia placeholder ao leitor de tela).

**Usar quando:** lista/tela com fetch perceptível (vazio, falha, carregando). **Não usar
quando:** erro inline mid-flow numa tela já populada (gerar PIN, validar check-in,
cronômetro) — esse é um banner recuperável local, micro-padrão à parte.

---

## `input.rating` (avaliação por estrelas — entrada)

**Descrição:** seletor de **1–5 estrelas obrigatório** da tela de avaliação recíproca.
Nasce na **STORY-084 / DDR-004** (EPIC-004). 5 estrelas tocáveis, estado vazio→selecionado;
ao escolher, um helper textual nomeia o valor ("Ótimo") — a estrela **não é só cor** (cheia
`★` vs contornada `☆` + acento do perfil). Sem seleção, o `button.primary` da tela fica
`disabled`; se forçado, vira erro vinculado ao grupo, nunca global.

**Flutter:** `Row` de `InkWell`/`IconButton` (o Material core não tem rating) — componente
custom do DS (mesma casa de `state_views.dart`). Alvo ≥48dp por estrela; navegável por
teclado (←/→ muda valor, Enter confirma).

| Estado | Comportamento |
|---|---|
| vazio | 5 estrelas contornadas, helper "Toque para avaliar" |
| n selecionado | 1..n preenchidas no `accent` do perfil; helper = rótulo (1 Ruim…5 Ótimo) |
| hover (web) | leve `scale`; foco anel `accent` |
| erro | helper vira "Escolha de 1 a 5 estrelas." em `error.ink`, `Semantics` no grupo |

**Acessibilidade:** `Semantics(label:'Avaliação, {n} de 5 estrelas')` no grupo; estrelas
internas decorativas. **Usar quando:** capturar nota 1–5. **Não usar para:** exibir nota
(use `display.rating`).

---

## `display.rating` (score / estrelas — leitura)

**Descrição:** exibição **read-only** da reputação: estrelas + número (1 casa) + contagem,
**ou** o selo **`badge.novo`** quando há **< 3 avaliações** (DDR-004 Eixo 2 — não inflar/
deflacionar com amostra mínima; limiar é parâmetro de produto em `business-rules.md`). Vale
para os dois papéis (profissional e contratante têm score). Variantes: **compacta** (linha de
topo do perfil: `4.9★ · 27 avaliações`) e **inline** (cabeçalho do `card.depoimento`).

**Flutter:** `Row` com estrelas (`ExcludeSemantics`) + `Text`; nó `Semantics` anuncia o
**número** ("4,9 de 5, 27 avaliações") ou o selo ("Novo na plataforma") — nunca depende de cor.

| Variante | Conteúdo |
|---|---|
| score (≥3) | `★★★★★` (acento) + `4.9★` + `· {n} avaliações` |
| novo (0) | `badge.novo` "Novo na plataforma" |
| novo (1–2) | `badge.novo` "Novo · {n} avaliação(ões)" |

**Usar quando:** mostrar reputação. **Não usar para:** capturar nota (`input.rating`).

---

## `badge.nivel` (nível do profissional)

**Descrição:** selo do nível na trilha do profissional — **Iniciante / Confiável / Destaque /
Elite** (`niveis-e-score.md`). Cor **neutra do perfil** (`accent.soft` + `accent.ink` + borda),
**não semântica**: nível não é alerta. **Só profissional** (contratante não tem nível no MVP —
DDR-004). Sobe automático e nunca rebaixa (ADR-019 high-water-mark).

**Flutter:** `Container` pílula (`radius.full`) com ícone + `Text` — mesma família visual de
`badge.status`, mas pintado no acento do perfil, não na cor semântica.

**Acessibilidade:** texto sempre presente (não só ícone); lido pelo leitor de tela.

---

## `meter.xp` (progresso de XP)

**Descrição:** barra de progresso "XP atual → XP até o próximo nível" + **rótulo textual**
("Faltam 320 XP para Destaque"). **Só profissional.** No nível **Elite** (topo), não há barra —
vira rótulo "Nível máximo alcançado". XP pode ficar negativo localmente sem rebaixar
(`niveis-e-score.md`); a barra clampa em 0.

**Flutter:** `LinearProgressIndicator` temável (track `surface.muted`, fill `accent`) com
`Semantics(value:'...')` + `Text` de rótulo. Nasce na STORY-084 / DDR-004.

---

## `card.depoimento`

**Descrição:** card de um depoimento no perfil público — `display.rating` (estrelas) +
comentário + **linha de autor** + data relativa. A linha de autor tem **duas variantes**
(DDR-004 — visibilidade assimétrica):

| Variante | Quando | Linha de autor |
|---|---|---|
| **estabelecimento** | depoimento **sobre profissional** (autor = contratante/PJ) | `{Nome do estabelecimento} · {Função} · {data relativa}` |
| **profissional-anônimo** | depoimento **sobre contratante** (autor = profissional/pessoa física) | `Profissional · {Função} · {data relativa}` — **sem nome individual** (LGPD) |

**Flutter:** `Card`/`Container` (`surface` + `radius.lg` + `elev.1`). Ordenado do mais recente
para o mais antigo; até **3** no perfil + `button.text` "Ver todas as avaliações (N)". Avaliação
**sem comentário não vira depoimento** (conta no score, não na lista).

**Acessibilidade:** estrelas decorativas; o nó do card anuncia estrelas (número) + comentário +
autor. **Atenção de contrato (LGPD):** o payload da variante profissional-anônimo **não** deve
trafegar `autor_id`/nome — só papel, função, estrelas, comentário, data.

---

## `badge.novo`

**Descrição:** selo neutro "Novo na plataforma" (+ contagem) exibido por `display.rating`
quando há **< 3 avaliações** (DDR-004). Família visual de badge neutro (`surface.sunken` +
`text.muted` + `border.strong`) — deliberadamente **discreto**, não compete com o acento.

**Flutter:** `Container` pílula (`radius.full`). Texto sempre presente.
