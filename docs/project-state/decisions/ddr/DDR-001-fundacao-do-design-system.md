---
id: DDR-001
title: Fundação do Design System — temas claro/escuro e esquema de cor por perfil
status: accepted
created_at: 2026-05-27
decided_at: 2026-05-27
approved_by: Alexandro
supersedes: ~
superseded_by: ~
related_ddrs: []
related_adrs: [ADR-001, ADR-007]
related_pdrs: [PDR-003, PDR-013]
scope: transversal
affects_screens: [SCREEN-STORY-008-hello-world-webapp]
---

# DDR-001 — Fundação do Design System (temas claro/escuro + esquema por perfil)

## Contexto

O EPIC-000 entrega "hello world" em homologação (STORY-008 WebApp, STORY-009 Backoffice). Sem fundação de Design System, cada tela do EPIC-001 em diante herdaria decisões visuais ad-hoc. DDR-001 fixa **tokens, tipografia, esquema de cor por perfil, temas, espaçamento, raio, elevação, motion e regras de uso** antes do produto ter UI séria.

**Fonte de verdade (revisada):** apenas o **PWA `docs/prototipo/app.html`**. A landing `docs/prototipo/index.html` é responsabilidade do time de marketing e sobe como está — **não** é referência do Design System do produto. Toda extração de token vem do `app.html`.

Documentos lidos: estória `STORY-010` (inteira) e `STORY-008`; `app.html` + `manifest.json`; `PDR-003` (duas interfaces); `ADR-001` (Flutter); `ADR-007` (RBAC por papel profissional/contratante/admin); `non-functional.md` (WCAG AA, texto mínimo, pt-BR, e — ponto de tensão — "tema escuro fora do MVP"); princípios de design.

**O que o `app.html` realmente é (verificado no código):**

- **Dual-theme nativo.** `:root` é o tema **claro** (off-white quente `#F7F4EC`); `[data-theme="dark"]` é o **escuro** (`#0F1411`). A função `initTheme()` detecta `prefers-color-scheme` e persiste a escolha em `localStorage`, com toggle. Ou seja: **a versão clara já existe** no protótipo — "derivar o claro" é formalizá-la e fechá-la em AA, não criá-la do zero.
- **Esquema de cor por perfil.** Cada papel tem seu hue, nos dois temas: profissional = verde-sage, contratante = mostarda, admin = vermelho no protótipo (**revisto para azul-navy nesta decisão — ver Decisão 3**). A sidebar é pintada por perfil e os acentos (CTA, ativo, chips, gradiente de fundo) seguem o hue do papel.
- **Dois verdes intencionais.** Marca `#00A868` (logo, `theme_color`) vs. verde-sage de interação `#2D5F3F` (CTA real de login/ativo). Branco sobre `#00A868` = 3.1:1 (reprova AA); sobre `#2D5F3F` = 7.4:1.

## Forças (drivers)

- **Persona não-técnica** (alto): legibilidade sem esforço nos dois temas, em pé na rua (profissional) ou jornada longa (admin/contratante).
- **Princípio #5 Acessibilidade** (alto): AA é critério de aceite (CA-6/CA-7). A marca não pode ser o CTA; cada acento de perfil precisa fechar AA em claro **e** escuro.
- **Fidelidade ao `app.html`** (alto): DDR-001 é **evolução coerente** do protótipo, não ruptura.
- **Identidade por perfil é load-bearing** (alto): o produto inteiro do protótipo distingue os papéis por cor; é orientação explícita do dono do produto manter isso.
- **Mapeamento Flutter** (médio-alto, ADR-001): tokens precisam virar `ThemeData`/`ColorScheme`/`TextTheme` sem ginástica — e perfil×tema precisa de um padrão limpo.
- **Custo de reversão** (médio): fundação visual e estratégia de tema são caras de trocar depois de N telas.

---

## Decisão 1 — Escala de espaçamento: 4pt vs 8pt

### Opção A — grade de 4pt pura
Todos múltiplos de 4. **Prós:** controle fino. **Contras:** opções demais → inconsistência; ritmo frouxo.

### Opção B — grade de 8pt com meio-passo de 4pt (escolhida)
8/16/24/32/48/64 governam o ritmo; `xs:4` cobre ajustes finos. **Prós:** previsível, poucos tokens, alinha com Material 3; o 4 resolve densidade do Backoffice. **Contras:** raro caso denso pede algo entre 4 e 8 — aceitável.

### Status quo — sem escala
Pixels soltos por tela. **Contras:** garante a entropia que DDR-001 evita.

**Decisão: B.** Disciplina de 8pt com válvula de escape de 4pt.

---

## Decisão 2 — Estratégia de tema: claro único vs dual claro+escuro

### Opção A — só tema claro no MVP (alinhado a `non-functional.md`)
Formaliza só o `:root`; escuro fica para depois.

- **Prós:** menos tokens agora; bate com "dark fora do MVP".
- **Contras:** **descarta** trabalho já feito no protótipo (o dark existe e é rico); retrabalho garantido quando o dark voltar; e o dono do produto pediu explicitamente para pensar o claro **derivado** do escuro existente — tratar como tema único ignora a realidade do `app.html`.

### Opção B — definir os dois temas como first-class; ligar conforme o PO decidir (escolhida)
A fundação **define** claro e escuro (neutros, acentos, semânticas em ambos), com seleção por `prefers-color-scheme` + toggle persistido (como o protótipo já faz). **O que o MVP liga** continua decisão do PO.

- **Prós:** zero retrabalho — o dark do protótipo é preservado e fechado em AA; coerência total com `app.html`; atende a orientação do dono do produto.
- **Contras:** mais pares de contraste a verificar (feito, §6 de `tokens.md`); **tensão com `non-functional.md`** ("dark fora do MVP") — precisa reconciliar com o PO (ver escalonamento).

### Status quo — sem tema formal
Cada tela escolhe cor. **Contras:** entropia.

**Decisão: B.** O dark não é trabalho novo — já está no protótipo. Defini-lo agora evita refazer a fundação depois; o gate de "o que liga no MVP" fica com o PO.

---

## Decisão 3 — Cor: acento único compartilhado vs esquema por perfil

### Opção A — um acento único para todo o produto
Um verde só conduz tudo, papéis se distinguem por outro meio (ícone, rótulo).

- **Prós:** paleta mínima, menos a manter.
- **Contras:** **contradiz a identidade do `app.html`** (papel = cor é assinatura do produto) e a orientação do dono; perde o reconhecimento instantâneo de contexto ("estou no admin" = vermelho) que ajuda o usuário não-técnico.

### Opção B — esquema de cor por perfil (escolhida)
Três esquemas — profissional (verde), contratante (mostarda), **admin (azul-navy)** — cada um com `accent`/`on-accent`/`soft`/`hover`/chrome, **em ambos os temas**. Mapeia para `ColorScheme.fromSeed(seed_do_perfil, brightness)` → 3 sementes × 2 brilhos = 6 `ColorScheme`. Pré-login usa o esquema neutro = profissional (verde), como o login do protótipo.

**Revisão admin: vermelho → azul-navy (2026-05-27, a pedido do Alexandro).** O protótipo usava vermelho como identidade do admin. Problema confirmado no preview do backoffice: o vermelho de **identidade** compete com o vermelho **semântico de erro/destrutivo** ("Recusar" some na cor da marca/sidebar). Trocar o admin para **azul-navy** (`#2A4D8F` claro / `#5B8DEF` escuro): (a) **libera o vermelho** para significar **só** erro/ação destrutiva, sem ambiguidade; (b) lê como "administrativo/confiável", tom adequado ao backoffice; (c) cria um overlap novo e **muito mais brando** com `info` (azul) — mitigado por um navy mais profundo/saturado que o `info` (`#4A6FA5`) e pelo fato de `info` ser semântica de baixa frequência.

- **Prós:** fiel à orientação do dono; contexto de papel legível de relance; de-para Flutter elegante (1 `fromSeed` por perfil×tema); EPIC-001 (cadastro de profissional **e** contratante) já encontra os esquemas prontos; vermelho passa a ser exclusivo de erro.
- **Contras:** mais tokens e mais verificação de contraste; sobreposição de hue (contratante≈warning, admin≈info) exige **regra de contexto** explícita.

### Status quo — `#00A868` como cor única de tudo
**Contras:** reprova AA (branco sobre `#00A868` = 3.1:1) e apaga a distinção de papel.

**Decisão: B.** A cor por perfil é identidade do produto e ajuda o usuário; o custo extra é verificação de contraste (feita) e uma regra de contexto para o overlap de hue.

---

## Avaliação contra os princípios (consolidado: 1B + 2B + 3B)

| Princípio | A's (único/claro/acento único) | **Escolhido (8pt + dual + por perfil)** | Status quo |
|---|---|---|---|
| 1. Simplicidade radical | ✅ menos tokens | ⚠️ mais tokens, mas estruturados por perfil×tema (1 `fromSeed` cada) | ❌ entropia |
| 2. Mobile-first com paridade | ✅ | ✅ tokens servem WebApp+Backoffice, claro+escuro | ⚠️ |
| 3. Tom profissional do domínio | ⚠️ perde identidade de papel | ✅ fiel ao `app.html`, sóbrio | ⚠️ |
| 4. Padronização > criatividade | ✅ | ✅ esquema fechado, sem cor avulsa | ❌ |
| 5. Acessibilidade como hábito | ⚠️ | ✅ AA verificado em claro e escuro, marca↔interação separadas | ❌ `#00A868` reprova |
| 6. Performance percebida | ✅ | ✅ flat; tint de perfil é decoração de baixa intensidade | ✅ |
| 7. Estados além do feliz | ✅ | ✅ semânticas nos dois temas + regra de feedback inline | ⚠️ |

> O ⚠️ em Simplicidade é assumido conscientemente: o produto **é** multi-perfil e multi-tema; a complexidade é essencial (existe no `app.html`), não acidental. Mitigada pela estrutura regular (perfil×tema = `fromSeed`).

## Decisão

> **Adotadas:** D1 = **8pt com meio-passo 4pt**; D2 = **dual-theme first-class (claro padrão + escuro), ligamento no MVP a cargo do PO**; D3 = **esquema de cor por perfil (profissional/contratante/admin) em ambos os temas**. Fundação completa em `docs/project-state/design/system/tokens.md`.

Pilares:

- **Marca:** `brand.green #00A868` — **só logomarca**.
- **Acento por perfil:** profissional verde (`#2D5F3F` claro / `#5FA37C` escuro), contratante mostarda (`#9A6E25`/`#D4A95C`), admin azul-navy (`#2A4D8F`/`#5B8DEF`). Pré-login = esquema profissional. **Vermelho não é cor de perfil** — reservado a erro/destrutivo.
- **Neutros por tema:** claro `#F7F4EC`/`#FFFFFF`/`#0F1B2D…`; escuro `#0F1411`/`#1A2018`/`#ECEDE5…`.
- **Semânticas por tema:** sucesso/atenção/erro/info (+ tons soft).
- **Tipografia:** Inter (texto), Bebas Neue (só logo), JetBrains Mono (overline restrito).
- **Espaçamento 8+4 · raio 8/12/16/24/full · elevação M3 0–3 · motion 100/200/300 · breakpoints M3.**

Força decisiva: **fidelidade ao `app.html` + identidade por perfil (orientação do dono) + acessibilidade**, equilibrando a complexidade essencial com uma estrutura regular (perfil×tema → `ColorScheme.fromSeed`).

## Consequências

### Positivas
- Cobre o produto real (multi-perfil, multi-tema) sem refazer fundação quando o dark/contratante/admin entrarem.
- De-para Flutter limpo: `ColorScheme.fromSeed(seedColor: <perfil>, brightness: <tema>)`, override de `surface`/`background` pelos neutros, semânticas como `ThemeExtension`, marca literal.
- Contexto de papel legível de relance — ajuda o usuário não-técnico.

### Negativas / trade-offs assumidos
- **Mais tokens e mais verificação de contraste** (6 ColorSchemes + semânticas). Mitigado pela regularidade e pela tabela §6.
- **Overlap de hue** contratante≈warning e admin≈info — resolvido por regra de contexto (perfil = identidade persistente; semântica = feedback transitório), que o time precisa respeitar. O overlap antigo e mais perigoso (admin≈error) foi **eliminado** ao mover o admin do vermelho para o azul.
- **Tensão com `non-functional.md`** ("dark fora do MVP"): a fundação define o dark, mas ligá-lo é decisão do PO — **escalonado** (abaixo).
- `text.subtle` no claro reprova AA normal (fica para texto grande/UI); no escuro passa.

### Impacto no Design System
- Reescreve `design/system/tokens.md` (v0.2): modelo tema×perfil, neutros/acentos/semânticas por tema, tipografia/espaçamento/raio/elevação/motion/breakpoints, tabelas de contraste claro **e** escuro. Atualiza `README.md` (status), `components.md` (acento é resolvido por perfil×tema), `patterns.md`, `voice-and-tone.md`.

### Impacto em telas existentes
- `SCREEN-STORY-008-hello-world-webapp`: pré-login → esquema **profissional (neutro)**, tema **claro por padrão** com suporte a escuro.
- STORY-009 (Backoffice, sem `requires_design`): aplica o esquema **admin** em nível mínimo via Livewire.

## Implementação sugerida (notas para o Programador)

- Um `ThemeData` por **perfil × tema**: `ColorScheme.fromSeed(seedColor: Color(0xFF2D5F3F | 0xFFB8842F | 0xFF2A4D8F), brightness: Brightness.light | dark)`; depois **fixe** `surface`/`background`/`onSurface` com os neutros de `tokens.md §3` e pine `primary`/`onPrimary`/`primaryContainer` nos valores de §2.2.
- **Brand `#00A868`** entra como cor literal da logomarca (`Text.rich`/SVG), fora do `ColorScheme`.
- **Semânticas** que não cabem no `ColorScheme` (success/warning/info) entram como `ThemeExtension` — não como cores cruas espalhadas.
- **Seleção de tema:** `MediaQueryData.platformBrightness` + override persistido (espelha `initTheme()` do protótipo). Respeite `MediaQuery.disableAnimations`.
- Pré-login força o esquema profissional; pós-login o esquema vem do papel do usuário (ADR-007).

## Critérios para revisitar
- **Reconciliar `non-functional.md` com o PO**: hoje diz "dark fora do MVP"; a fundação define dark. Decidir se o MVP liga dark ou só claro (a fundação suporta ambos sem mudança).
- Quando a **cromática de pré-cadastro** (amarelo/azul do protótipo) for necessária — adicionar como sub-estados dos perfis, revalidando contraste.
- Se o overlap de hue (contratante/warning, admin/error) gerar confusão real em uso — reavaliar.
- Após ~5 telas consumindo a fundação — podar/expandir tokens conforme dor real.

## Escalonamento

- **[ESCALONAMENTO-PO] — RESOLVIDO em 2026-05-27 via PDR-013.** Verificou-se que `non-functional.md` era **silente** sobre temas (a suposição "dark fora do MVP" estava só em estórias, sem lastro). O PO registrou **PDR-013** (dual-theme suportado; padrão do MVP = claro) e adicionou a seção "Temas (aparência)" em `non-functional.md`. A fundação dual-theme deste DDR está alinhada à decisão de produto.

## Aprovação humana

| Campo | Valor |
|---|---|
| Apresentado em | 2026-05-27 |
| Aprovado por | Alexandro |
| Data da aprovação | 2026-05-27 |
| Observações do aprovador | Aprovado após revisões: fonte = só `app.html`; dual-theme (claro padrão + escuro, PDR-013); esquema por perfil; **admin movido de vermelho para azul-navy** (libera o vermelho para erro). Validado nos previews de tema×perfil e do backoffice. |

> DDR-001 `accepted`. A fundação em `design/system/` é a referência vigente; STORY-008/009 podem aplicá-la como definitiva.
