---
id: SCREEN-STORY-084-avaliacao-e-perfil
story: STORY-084-spike-designer-depoimentos-telas-perfil
epic: EPIC-004-avaliacao-reciproca
status: ready                # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-09
updated_at: 2026-06-09
owner_designer: claude-opus-4-8
related_ddrs: [DDR-004, DDR-003, DDR-002, DDR-001]
ds_components_used:
  - input.rating
  - display.rating
  - badge.nivel
  - meter.xp
  - card.depoimento
  - banner.gate
  - input.text
  - button.primary
  - button.text
  - surface.card
  - badge.status
  - section.group-header
  - state.empty
  - state.error
  - state.loading
  - pattern.navigation
exceptions_to_ds: []
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-084-avaliacao-e-perfil/index.html
prototype_last_validated_at: 2026-06-09
---

# Spec de tela — Avaliação recíproca + Perfil (reputação) + UX do gate

> Referência: estória `STORY-084` (CAs e contexto vêm de lá — **não duplico**).
> Decisões que regem este spec: **DDR-004** (visibilidade de depoimentos, score com poucos dados, componentes de reputação), **ADR-019** (modelo/eventos/motor/gate), `flows/avaliacao-reciproca.md`.
> Tudo dentro do **shell** (DDR-003), pt-BR/24h (DDR-002), AA por construção sobre tokens DDR-001.

Este spec cobre o **cluster** de superfícies do EPIC-004 (uma estória de design → uma pasta de protótipo). São **quatro superfícies**:

- **T1** — Tela de avaliação **profissional → contratante**.
- **T2** — Tela de avaliação **contratante → profissional** (espelho de T1; mesma estrutura, copy adaptada).
- **T3** — Bloco de **reputação no Perfil** (score / nível / XP / depoimentos) — profissional **e** contratante (reciprocidade).
- **T4** — **UX do gate bloqueante** (`banner.gate`) nos destinos onde a ação bloqueada vive.

A implementação se divide entre STORY-087 (T1+T2) e STORY-088 (T3+T4) — ver épico.

---

## 1. Objetivo de cada superfície

- **T1/T2:** capturar, em um toque + um campo opcional, a avaliação que o usuário **precisa** dar para destravar a próxima ação. A UMA tarefa: *dar estrelas (obrigatório) e, se quiser, um comentário*.
- **T3:** comunicar **de relance** a reputação de uma pessoa/estabelecimento: quão bem avaliado, em que nível está (profissional), quanto falta para subir, e o que dizem dele.
- **T4:** quando há avaliação pendente, **avisar antes** de o usuário bater na parede e levá-lo direto ao turno a avaliar.

Se alguma destas precisasse de tutorial, estaria errada — são todas de uma tarefa só.

## 2. Fluxo

### T1/T2 — Avaliação

**Entrada.**
- Pela **notificação/deep-link** "Avalie seu turno" (in-app + e-mail, disparada por `TurnoFinalizado` — fluxo passo 1).
- Pelo **`banner.gate`** (T4) ao tentar nova ação com pendência → CTA "Avaliar agora" deep-linka ao `turno_id` pendente mais antigo.
- A partir do **detalhe do turno** finalizado (SCREEN-060), seção de avaliação.
- **Pré-condições:** sessão ativa; turno em `finalizado`/`finalizado_ajustado`; a direção do usuário **ainda pendente** (não existe linha em `avaliacoes` para `(turno_id, direcao)` — ADR-019).

**Ações possíveis.**
- Primária: **selecionar estrelas (1–5, obrigatório)** e **Enviar avaliação**.
- Secundária: escrever **comentário (opcional, ≤ 280)**; **Voltar** (sai sem enviar — a pendência continua).
- Saídas: sucesso → confirmação curta + volta ao contexto de origem (turno / feed) com a pendência **resolvida** naquela direção; o gate correspondente deixa de bloquear.

**Saída.**
- **Sucesso:** `SnackBar` "Avaliação enviada. Obrigado!" + retorno; se a ação que originou o desvio era candidatar-se/publicar, o usuário pode retomá-la.
- **Cancelamento (Voltar):** nada é gravado; pendência permanece; gate continua valendo.
- **Erro recuperável:** mensagem inline + botão mantém o estado preenchido (não perde estrelas/comentário).

### T3 — Reputação no Perfil

**Entrada.** Destino **Perfil** do shell (DDR-003) — o próprio usuário; ou drill-down "perfil público" (futuro: candidato no painel do contratante). O bloco de reputação fica **acima** de Preferências/Sair (que já existem — `perfil_screen.dart`).

**Ações.** Ler. **"Ver todas as avaliações (N)"** → lista completa de depoimentos (drill-down dentro do destino Perfil, mantém shell). Sem ações de escrita aqui.

**Saída.** Voltar mantém o shell.

### T4 — Gate

**Entrada.** O usuário abre o destino onde mora a ação bloqueada: **Vagas/feed** (profissional, para candidatar-se) ou **Nova vaga / Minhas vagas** (contratante, para publicar). Se há ≥1 avaliação pendente do **seu papel**, o `banner.gate` aparece no topo.

**Ações.** **"Avaliar agora"** → deep-link ao turno pendente (T1/T2). O banner **não é dispensável** (é bloqueio, não aviso). Tentar a ação bloqueada mesmo assim (ex.: tocar "Candidatar-se" numa vaga) → o serviço devolve `gate_avaliacao` e o app reexibe/realça o banner (não um erro técnico cru).

**Saída.** Quando a última pendência do papel é resolvida, o banner some e a ação volta a funcionar (≤1s após a avaliação, motor recomputa — fluxo passo 4/6).

---

## 3. Layout

### T1/T2 — Avaliação · Mobile (≥360px)

```
+--------------------------------+
| ‹ Avaliar turno          [🔔] |  ← AppBar do shell (drill-down empilha dentro do destino)
+--------------------------------+
|  Restaurante Vista Mar         |  ← quem você está avaliando (contexto do turno)
|  Garçom · 12/06, 18:00–23:00   |  ← função + janela do turno (24h, DDR-002)
|                                |
|  Como foi trabalhar aqui?      |  ← pergunta (T1: contratante; T2: profissional)
|     ★  ★  ★  ★  ★              |  ← input.rating (obrigatório) — alvos ≥48dp
|     Toque para avaliar          |  ← helper; vira "Bom" / "Ótimo" etc. ao escolher
|                                |
|  Comentário (opcional)         |
|  +--------------------------+  |
|  | Conte como foi...        |  |  ← input.text multiline, ≤280
|  +--------------------------+  |
|                          0/280 |
|                                |
+--------------------------------+
|  [ Enviar avaliação ]          |  ← button.primary (fixo no rodapé; disabled até ≥1★)
+--------------------------------+
```

- Componentes do DS: `input.rating`, `input.text`, `button.primary`, `button.text` (Voltar via AppBar back), `surface.card` (bloco de contexto do turno).
- Estrelas grandes e centradas (alvo ≥48dp cada); rodapé de CTA fixo (padrão das telas de ação 061/064). Comentário é claramente **opcional** no label.

### T1/T2 — Avaliação · Desktop (≥1024px)

```
+----------+-----------------------------------------------+
| TURNI.   | Avaliar turno                          🔔 ☾  |  ← header de conteúdo (DDR-003)
| [nav     +-----------------------------------------------+
|  drawer] |   ┌─────────────────────────────────────────┐ |
|          |   │ Restaurante Vista Mar                     │ |  ← card de contexto centrado,
|          |   │ Garçom · 12/06, 18:00–23:00               │ |    largura máx ~560px (não esticar)
|          |   │                                           │ |
|          |   │ Como foi trabalhar aqui?                  │ |
|          |   │      ★  ★  ★  ★  ★    Ótimo               │ |
|          |   │ Comentário (opcional)                     │ |
|          |   │ [textarea ............................]   │ |
|          |   │                                    0/280  │ |
|          |   │            [ Voltar ]  [ Enviar avaliação]│ |
|          |   └─────────────────────────────────────────┘ |
+----------+-----------------------------------------------+
```

- Não é "mobile esticado": no desktop a tela é um **card centrado de largura limitada** (≤560px) — tarefa focada, sem espalhar campos pela largura toda. CTA volta para dentro do card, par "Voltar / Enviar".

### T3 — Reputação no Perfil · Mobile

```
+--------------------------------+
|  (●)  Ana Souza                |  ← identidade (já existe)
|       Profissional             |
|                                |
|  ┌──────────────────────────┐  |
|  │  4.9★   Confiável  🛡     │  │  ← display.rating + badge.nivel (só profissional)
|  │  27 avaliações            │  │
|  │  XP ▓▓▓▓▓▓▓░░░  680/1000   │  │  ← meter.xp (só profissional)
|  │  Faltam 320 XP p/ Destaque │  │
|  └──────────────────────────┘  |
|                                |
|  DEPOIMENTOS                   |  ← section.group-header
|  ┌──────────────────────────┐  |
|  │ ★★★★★  "Pontual e ..."    │  │  ← card.depoimento (variante estabelecimento)
|  │ Restaurante Vista Mar ·    │  │
|  │ Garçom · há 3 dias         │  │
|  └──────────────────────────┘  |
|  ┌──────────────────────────┐  |
|  │ ★★★★☆  "Ótima postura."   │  │
|  │ Bar do Porto · Garçom ·    │  │
|  │ há 2 semanas               │  │
|  └──────────────────────────┘  |
|  Ver todas as avaliações (27)  |  ← button.text → lista completa
|  ───────────────────────────  |
|  Preferências  ·  Sair         |  ← já existem (perfil_screen.dart)
+--------------------------------+
```

- **Contratante (T3):** mesmo bloco **sem** `badge.nivel` e **sem** `meter.xp` (sem nível/XP no MVP) — só `display.rating` (score + contagem) e depoimentos na **variante profissional-anônimo** ("Profissional · Garçom · há 1 semana").
- Componentes: `display.rating`, `badge.nivel`, `meter.xp`, `card.depoimento`, `section.group-header`, `button.text`, `surface.card`.

### T3 — Reputação no Perfil · Desktop

```
+----------+-----------------------------------------------+
| nav      | Perfil                                  🔔 ☾  |
| drawer   +-----------------------------------------------+
|          |  (●) Ana Souza · Profissional                 |
|          |  ┌───────────────────────┐  DEPOIMENTOS       |  ← 2 colunas: resumo à esq,
|          |  │ 4.9★  Confiável 🛡    │  ┌───────────────┐ |    depoimentos à dir
|          |  │ 27 avaliações         │  │ ★★★★★ "..."   │ |
|          |  │ XP ▓▓▓▓▓▓▓░ 680/1000  │  │ Rest. Vista..│ |
|          |  │ Faltam 320 p/ Destaque│  └───────────────┘ |
|          |  └───────────────────────┘  ┌───────────────┐ |
|          |                              │ ★★★★☆ "..."   │ |
|          |                              └───────────────┘ |
|          |                              Ver todas (27)     |
+----------+-----------------------------------------------+
```

- O espaço extra do desktop vira **duas colunas** (resumo de reputação | lista de depoimentos), não cards esticados.

### T4 — Gate · Mobile e Desktop

```
mobile (feed do profissional)            desktop (minhas vagas do contratante)
+--------------------------------+       +----------+--------------------------------+
| Vagas                    [🔔] |       | nav      | Minhas vagas            🔔 ☾  |
+--------------------------------+       | drawer   +--------------------------------+
| ┌────────────────────────────┐ |      |          | ┌────────────────────────────┐ |
| │ ⚠ Avalie seu último turno   │ |      |          | │ ⚠ Avalie seu último turno   │ |
| │   para se candidatar.       │ |      |          | │   para publicar uma vaga.   │ |
| │            [ Avaliar agora ]│ |      |          | │            [ Avaliar agora ]│ |
| └────────────────────────────┘ |      |          | └────────────────────────────┘ |
| (feed de vagas segue visível)  |       |          | (lista de vagas segue visível) |
+--------------------------------+       +----------+--------------------------------+
```

- `banner.gate` no **topo do destino**, abaixo do header, acima do conteúdo. O conteúdo (feed/lista) **continua visível** — o gate bloqueia a **ação**, não a visibilidade (fluxo §gate). Warning soft (`warn.soft` + ícone + texto — nunca só cor). CTA "Avaliar agora" alinhado à direita.

## 4. Estados

> Todos os estados aplicáveis. Cada um alcançável no protótipo (§9).

### 4.1. Caminho feliz
- **T1/T2:** ≥1 estrela escolhida → CTA habilita → enviar → SnackBar de sucesso. Microcopy §5.
- **T3:** score ≥3 avaliações exibe média 1-casa + nível/XP (prof); depoimentos preenchidos.
- **T4:** banner com a mensagem do papel + CTA.

### 4.2. Loading (primeiro fetch e refresh)
- **T1/T2:** carregando o contexto do turno → skeleton do bloco de contexto (`state.loading` / `TurniSkeletonBox`) — estrelas e CTA já visíveis (não dependem de rede).
- **T3:** `state.loading` no formato do bloco de reputação + ~3 skeletons de `card.depoimento`. **Nunca** spinner em tela branca (Princípio #6).
- **T4:** o banner só aparece após saber que há pendência; enquanto não sabe, não pisca banner (evita flash).

### 4.3. Vazio
- **T3 sem nenhuma avaliação:** `display.rating` mostra **selo "Novo na plataforma"** (DDR-004 Eixo 2); seção de depoimentos com `state.empty`: "Ainda sem avaliações" + instrução ("Complete turnos para receber suas primeiras avaliações."). Profissional novo ainda mostra nível **Iniciante** + XP inicial.
- **T3 com score mas sem nenhum comentário** (só estrelas): score/nível/XP normais; seção de depoimentos com `state.empty` leve: "Ainda sem comentários" + "As avaliações com comentário aparecem aqui."
- **T3 com 1–2 avaliações:** selo "Novo · N avaliação(ões)"; depoimentos que tiverem comentário já aparecem.
- **T4 sem pendência:** banner **ausente** (estado normal do feed).

### 4.4. Erro
- **T1/T2 — envio falhou (rede):** banner inline recuperável acima do CTA — "Não foi possível enviar agora. Tente de novo." + o estado preenchido **permanece**; botão volta de loading para ativo. (Micro-padrão de erro mid-flow — `patterns.md`, não `state.error` de tela inteira.)
- **T1/T2 — já avaliado / pendência inexistente (409 do `UNIQUE`):** estado informativo, não erro cru — "Você já avaliou este turno." + CTA "Voltar". Evita reenvio (ADR-019: `UNIQUE (turno_id, direcao)`).
- **T1/T2 — estrelas não escolhidas:** o CTA fica **disabled**; se o usuário tentar enviar via teclado, helper vira erro associado: "Escolha de 1 a 5 estrelas." (vinculado ao `input.rating`, não global).
- **T3 — falha ao carregar reputação:** `state.error` (`TurniRetryState`) "Não foi possível carregar a reputação." + "Tentar de novo". As Preferências/Sair abaixo continuam funcionando.
- **T4 — ação tentada com gate ativo:** o app **não** mostra erro técnico; realça o banner e (se veio de um toque na ação) leva à avaliação. `gate_avaliacao` nunca vaza como código ao usuário.

### 4.5. Sem permissão
- **T1/T2 — turno não é do usuário / RBAC cruzado:** `state.empty` não-recuperável (ícone `lock_outline`) "Este turno não é seu." + "Voltar aos meus turnos" (padrão `pattern.error` não-recuperável). Fail-secure coerente com ADR-019.
- **T3 perfil de outro papel:** sem nível/XP quando o perfil é de contratante (não é erro — é a regra do MVP).

### 4.6. Parcial / degradado
- **T3:** se reputação carrega mas depoimentos falham → mostra score/nível/XP e um `state.error` **só na seção** de depoimentos (retry local), sem derrubar o bloco todo.

### 4.7. Primeira vez vs recorrente
- **T1/T2 primeira avaliação do usuário:** uma linha de contexto extra discreta sob a pergunta — "Sua avaliação ajuda a manter a confiança entre os dois lados." (some nas próximas). Sem modal, sem tour.

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| **T1** título (AppBar) | Avaliar turno |
| **T1** pergunta (prof→contratante) | Como foi trabalhar aqui? |
| **T1** contexto | {Nome do estabelecimento} · {Função} · {dd/MM, HH:mm–HH:mm} |
| **T2** pergunta (contratante→prof) | Como foi o trabalho de {Primeiro nome}? |
| **T2** contexto | {Primeiro nome do profissional} · {Função} · {dd/MM, HH:mm–HH:mm} |
| Helper do rating (vazio) | Toque para avaliar |
| Helper do rating (preenchido) | 1★ "Ruim" · 2★ "Regular" · 3★ "Bom" · 4★ "Muito bom" · 5★ "Ótimo" |
| Erro rating obrigatório | Escolha de 1 a 5 estrelas. |
| Label comentário | Comentário (opcional) |
| Placeholder comentário | Conte como foi… |
| Contador comentário | {n}/280 |
| CTA primário (T1/T2) | Enviar avaliação |
| CTA secundário (desktop) | Voltar |
| Onboarding 1ª vez | Sua avaliação ajuda a manter a confiança entre os dois lados. |
| Sucesso (SnackBar) | Avaliação enviada. Obrigado! |
| Erro de envio (rede) | Não foi possível enviar agora. Tente de novo. |
| Já avaliado (409) | Você já avaliou este turno. |
| Sem permissão (título) | Este turno não é seu. |
| Sem permissão (CTA) | Voltar aos meus turnos |
| **T3** header de seção | DEPOIMENTOS |
| **T3** selo Novo (0) | Novo na plataforma |
| **T3** selo Novo (1–2) | Novo · {n} avaliação / {n} avaliações |
| **T3** score (≥3) | {x.x}★ · {n} avaliações |
| **T3** nível (badge) | Iniciante / Confiável / Destaque / Elite |
| **T3** XP (rótulo) | Faltam {k} XP para {próximo nível} |
| **T3** XP (nível máximo) | Nível máximo alcançado |
| **T3** autor — sobre profissional | {Nome do estabelecimento} · {Função} · {data relativa} |
| **T3** autor — sobre contratante | Profissional · {Função} · {data relativa} |
| **T3** ver todas | Ver todas as avaliações ({n}) |
| **T3** vazio sem avaliações (título) | Ainda sem avaliações |
| **T3** vazio sem avaliações (instrução) | Complete turnos para receber suas primeiras avaliações. |
| **T3** vazio sem comentários (título) | Ainda sem comentários |
| **T3** vazio sem comentários (instrução) | As avaliações com comentário aparecem aqui. |
| **T3** erro reputação | Não foi possível carregar a reputação. |
| **T4** banner (profissional) | Avalie seu último turno para se candidatar. |
| **T4** banner (contratante) | Avalie seu último turno para publicar uma nova vaga. |
| **T4** banner CTA | Avaliar agora |
| Notificação subiu de nível (in-app) | Parabéns! Você alcançou o nível {Confiável/Destaque/Elite}. |

> Datas relativas pt-BR: "há 3 dias", "há 1 semana", "há 2 meses"; > ~30 dias → `dd/MM/aaaa` (DDR-002).
> Vocabulário do glossário do PO ("Turno", "Vaga", "Profissional", "Contratante"). Mensagens de gate seguem `flows/avaliacao-reciproca.md`.

## 6. Acessibilidade (notas específicas)

- **`input.rating`:** cada estrela é alvo ≥48dp; navegável por teclado (setas ←/→ mudam o valor, Enter confirma). `Semantics` do grupo anuncia "Avaliação, {n} de 5 estrelas"; helper textual ("Ótimo") **duplica** a informação que a cor das estrelas dá — estrela cheia/vazia não é só cor (ícone preenchido × contornado). Erro vinculado ao grupo (não global).
- **`display.rating`:** estrelas decorativas (`ExcludeSemantics`); o nó semântico anuncia o **número** ("4,9 de 5, 27 avaliações") ou o selo ("Novo na plataforma"). Não depender da cor.
- **`badge.nivel` / `meter.xp`:** badge tem texto (não só ícone); a barra de XP tem rótulo textual ("Faltam 320 XP para Destaque") — `LinearProgressIndicator` com `Semantics(value:)`.
- **`banner.gate`:** `Semantics(liveRegion: true)` ao aparecer; cor `warning` acompanhada de ícone + texto (regra de ouro tokens §4). CTA "Avaliar agora" ≥48dp, foco visível.
- **Ordem de foco T1/T2:** contexto → rating → comentário → CTA. Foco inicial no **rating** (a tarefa). SnackBar de sucesso com `liveRegion`.
- **Contraste:** todos os pares são tokens sancionados (DDR-001 §6). Estrela preenchida usa o **acento do perfil** (sage/mostarda) sobre `surface` — par ≥3:1 (UI/ícone grande) ✅; o número do score usa `text.strong` ✅.
- **Alvos ≥48dp:** ✅ (estrelas, CTA, "Ver todas", "Avaliar agora").

## 7. Identificadores estáveis sugeridos

| Elemento | Identificador lógico sugerido |
|---|---|
| Grupo de estrelas (input) | `avaliacao-estrelas` |
| Estrela n (input) | `avaliacao-estrela-{n}` |
| Campo de comentário | `avaliacao-comentario` |
| CTA enviar | `avaliacao-enviar-btn` |
| Erro de rating | `avaliacao-estrelas-erro` |
| Banner de erro de envio | `avaliacao-envio-erro` |
| Score no perfil | `perfil-score` |
| Badge de nível | `perfil-nivel-badge` |
| Barra de XP | `perfil-xp-meter` |
| Seção de depoimentos | `perfil-depoimentos` |
| Lista de depoimentos | `depoimento-list` |
| Item de depoimento | `depoimento-item-{id}` |
| Ver todas | `perfil-ver-todas-btn` |
| Estado vazio de depoimentos | `perfil-depoimentos-vazio` |
| Banner do gate | `gate-banner` |
| CTA do gate | `gate-avaliar-btn` |

## 8. Exceções ao Design System

Nenhuma. Todos os componentes novos (`input.rating`, `display.rating`, `badge.nivel`, `meter.xp`, `card.depoimento`, `banner.gate`) entram no DS via **DDR-004** **antes** de aparecerem aqui — registrados em `components.md`/`patterns.md` na mesma operação. Sem desvio.

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-084-avaliacao-e-perfil/index.html` (sibling deste spec).
- **Cobertura:** seletores no topo — **Tela** (Avaliar / Perfil / Gate) × **Papel** (Profissional / Contratante) × **Viewport** (Mobile / Desktop) × **Estado** (preenchido / loading / vazio / enviando / sucesso / erro). Todos os estados da §4 alcançáveis.
- **Fidelidade:** tokens reais DDR-001 (acento por perfil, neutros, raios, motion); microcopy = §5 palavra por palavra; chrome do shell (DDR-003) reusado do protótipo SCREEN-077. Identificadores da §7 aplicados como `id`/`data-testid`.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, sem build; mocks inline; topo declara "protótipo de validação, não produção".
- **Como apresentar:** abrir `index.html` no navegador para o dono validar; capturar "vai"/ajustes e registrar `prototype_last_validated_at` + §11.

### Checklist antes de `ready`
- [x] `index.html` existe e abre sem erro.
- [x] Todos os estados da §4 acessíveis pelo seletor.
- [x] Mobile e desktop navegáveis.
- [x] Microcopy do protótipo = §5.
- [x] Identificadores da §7 presentes.
- [x] Caminho feliz percorrível (gate → avaliar → sucesso; perfil atualizado).
- [x] Tokens reais do DS.
- [x] **Protótipo apresentado ao humano e sinal de validação capturado** — aprovado pelo dono em 2026-06-09 (ver §11).

## 10. Dependências e premissas

- **API (ADR-019 / STORY-085/086):** front **só lê** score/nível/XP/contagem já recomputados (`profissional_profiles`/`contratante_profiles`); escreve a avaliação (`POST` que insere em `avaliacoes`, respeitando `UNIQUE (turno_id, direcao)`); o gate devolve `gate_avaliacao` + `turno_id` para o deep-link.
- **Contrato de leitura (LGPD — DDR-004):** depoimentos do **contratante** NÃO trafegam `autor_id`/nome do profissional — só `papel`, `funcao`, `estrelas`, `comentario`, `data`.
- **Shell (DDR-003):** todas as superfícies vivem dentro do shell; avaliação é drill-down empilhado no destino; banner do gate fica no topo do destino.
- **Parâmetros de produto:** limiar do selo "Novo" (=3), limiares de nível (500/1000/3000), pesos de XP — vêm de `business-rules.md`, não do design.
- **Premissa de back:** subida de nível dispara notificação in-app (fluxo); o "Parabéns! nível X" é notificação (SCREEN-053), não tela própria.

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-09 | criação (spec + protótipo v1) | claude-opus-4-8 (designer) | spike STORY-084 — DDR-004 ratificado pelo dono; specs das 4 superfícies + protótipo navegável mobile/desktop com todos os estados |
| 2026-06-09 | validação humana | Alexandro | protótipo apresentado ao dono no navegador; **aprovado** (sem ajustes). Destrava STORY-087/088. |
