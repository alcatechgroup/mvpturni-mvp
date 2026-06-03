---
id: SCREEN-STORY-052-editar-vaga-e-diff
story: STORY-052-edicao-material-vaga-pdr009
epic: EPIC-002-vaga-feed-e-candidatura
status: shipped            # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-02
updated_at: 2026-06-02
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [surface.card, button.primary, button.text, button.outline, cadastro.section, cadastro.textfield, cadastro.errortext, banner.warning, banner.error, gate.banner, diff.row, badge.status]
exceptions_to_ds: [diff.row (linha "campo: antes → depois" do preview e do banner — 1º uso no app; reusa surface.card + token de cor de texto forte/mudo, sem componente novo no DS — §8), banner.revisao (faixa de revisão pós-edição no detalhe/feed do profissional — reusa banner.warning com prazo + 2 ações — §8)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-052-editar-vaga-e-diff/index.html
prototype_last_validated_at: 2026-06-02   # validado por Alexandro no browser (aprovado em chat)
---

# Spec de tela — SCREEN-STORY-052 — Editar vaga + diff (contratante) e banner de revisão (profissional)

> Referência: estória `STORY-052`. CAs e contexto vêm de lá — **não duplico**.
> Esta estória tem **dois sujeitos** num único ciclo de confiança (PDR-009):
> **A) contratante** edita uma vaga que **já tem gente olhando** e vê, antes de salvar, o
> **diff material** e **quantos candidatos serão avisados**;
> **B) profissional** com candidatura naquela vaga recebe um **banner de revisão** ("a vaga
> mudou — confirme em até 24h") e decide **manter** ou **retirar**.
> Telas-mãe: A reusa o **formulário de publicar vaga** (`SCREEN-STORY-046`) e é aberta pelo card
> de "Minhas vagas" (`SCREEN-STORY-047`); B reusa o **card do feed** (`SCREEN-STORY-048`, filtro
> "Candidatadas") e o **detalhe da vaga** (`SCREEN-STORY-049`).
> Fundação visual: `DDR-001` + `docs/project-state/design/system/`. Locale/horário: `DDR-002`
> (pt-BR, 24h — nunca AM/PM). Estados de candidatura: `domain/candidatura.md` + STORY-044.
> Temas de papel (DDR-001): A no acento **mostarda** do contratante; B no acento **verde-sage**
> do profissional.
> Princípios que guiaram: **#1** simplicidade (editar é o mesmo form que publicar + UM passo de
> confirmação; o profissional vê UMA pergunta: manter ou sair), **#2** mobile-first (o gestor
> corrige a vaga do celular; o profissional decide do celular entre turnos), **#3** tom
> profissional (o diff é honesto e factual, sem alarme), **#5** WCAG AA (mudança nunca só por
> cor — antes/depois em texto + ícone + seta), **#6** performance percebida (skeleton no load do
> form, otimismo no confirmar/retirar), **#7** todos os estados (loading, sem permissão, vaga não
> editável/409, nada mudou, sem candidatos, com candidatos, prazo expirado, erro de rede).

Esta tela **fecha a parte sensível do PDR-009**: editar depois de já ter candidatos sem quebrar
confiança. O contratante **nunca** muda algo material em silêncio — ele vê o diff e o número de
pessoas afetadas antes de confirmar. O profissional **nunca** confirma um turno cujo valor/horário
mudou sem ver o quê — ele recebe o diff e tem 24h (ou até o turno começar) para decidir.

---

## Tema e perfil

- **Surface A (contratante dono da vaga)** → tema do papel (DDR-001): acento **mostarda**
  (`#9A6E25` claro / `#D4A95C` escuro; tinta de texto/link `#6E4E12` claro). Mesmo tema de
  "Publicar vaga" (046) e "Minhas vagas" (047) — continuidade mãe→filha. O CTA "Confirmar
  alteração" usa o acento mostarda; o "Voltar/Cancelar" é `button.text`.
- **Surface B (profissional dono da candidatura)** → tema do papel: acento **verde-sage**
  (`#2D5F3F` claro / `#5FA37C` escuro). O botão "Manter candidatura" usa o acento verde; "Retirar"
  é `button.outline` neutro (ação destrutiva leve, sem vermelho — retirar não é erro).
- **Cor da revisão (`banner.warning`):** a faixa "a vaga foi editada" usa a cor **atenção**
  (mostarda-soft `warnSoft`) com ícone ⚠/✎ — é aviso, não erro. Independe do acento do papel: é
  "estado do match", não chrome. O **prazo** ("confirme até …") é o gancho de urgência, em texto
  forte, nunca só em vermelho.
- **Diff (`diff.row`):** cada linha mostra **rótulo do campo** + **valor antigo** (texto mudo,
  riscado opcional) + **seta →** + **valor novo** (texto forte). A diferença é legível sem cor
  (ícone + seta + dois valores) — WCAG AA (#5). Mesmo componente serve o preview do contratante e
  o banner do profissional (simetria: os dois veem o **mesmo** diff).

---

## 1. Objetivo da tela

- **A (contratante):** corrigir uma vaga publicada e, **antes de salvar**, ver exatamente o que
  muda e quantos candidatos serão avisados — decidir com informação, não às cegas.
- **B (profissional):** ao ser avisado de que a vaga que me candidatei mudou, ver o que mudou e
  **manter** ou **retirar** a candidatura dentro do prazo.

---

## 2. Fluxo

### Surface A — Editar vaga (contratante)

**Entrada**
- Card de "Minhas vagas" (047): ação nova **"Editar"** (menu/overflow do card de vaga `aberta`).
  Rota `/contratante/vagas/{id}/editar`. Deep-link direto também é válido.
- Pré-requisito: sessão `ativa` + papel `contratante` + ser **dono** da vaga + vaga `aberta`.
  Vaga `fechada`/`cancelada` → não é editável (estado 4.5/409).
- Ao abrir, carrega os valores **atuais** da vaga (GET de edição) + a contagem de candidatos
  pendentes (quem será avisado). Pré-preenche o mesmo form de publicar (046).

**Ações possíveis**
- Editar qualquer um dos campos materiais: Função, Início, Fim, Valor, Quantas pessoas,
  Observações (todos materiais — PDR-009).
- **Ação primária:** "Revisar alteração" → abre o **passo de confirmação** com o diff.
- No passo de confirmação: **"Confirmar alteração"** (commit) ou **"Voltar e ajustar"** (volta ao
  form sem efeito).
- **Saída:** cancelar/voltar → "Minhas vagas" sem efeito.

**Saída**
- **Sucesso (material, com candidatos):** volta para "Minhas vagas" com toast "Vaga atualizada —
  N candidato(s) foram avisados e têm 24h para confirmar."
- **Sucesso (material, sem candidatos):** toast "Vaga atualizada."
- **Sucesso (nada material mudou / só ajuste livre):** toast "Vaga atualizada." (sem aviso).
- **Cancelamento:** volta sem efeito.
- **Erro recuperável (rede/5xx):** permanece no passo de confirmação com banner + "Tentar de novo";
  o rascunho é preservado.
- **409 (vaga deixou de ser editável entre o load e o submit):** banner "Esta vaga não pode mais
  ser editada" + botão "Ver a vaga".

### Surface B — Banner de revisão (profissional)

**Entrada**
- A candidatura do profissional passou a `pendente_revisao_apos_edicao` (o contratante fez uma
  edição material). O profissional chega por: card no feed (filtro **"Candidatadas"**) com selo
  "Vaga editada — confirme", ou abrindo o **detalhe** (049) da vaga.
- Pré-requisito: sessão `ativa` + papel `profissional` + ter candidatura
  `pendente_revisao_apos_edicao` nessa vaga.

**Ações possíveis**
- No card do feed: o selo é informativo; tocar o card abre o detalhe (onde estão as ações).
- No detalhe: banner de revisão com o diff (o que mudou) + prazo. **Ação primária:** "Manter
  candidatura" → candidatura volta a `pendente`. **Ação secundária:** "Retirar" →
  `retirada_por_edicao` (confirmação leve antes).
- **Saída:** após manter → banner some, candidatura segue `pendente` (volta ao estado normal de
  "candidatado"). Após retirar → estado "candidatura retirada".

**Saída**
- **Manteve:** toast "Candidatura mantida." + o detalhe volta ao estado normal de candidatado.
- **Retirou:** toast "Candidatura retirada." + o detalhe mostra "Você não está mais candidatado".
- **Prazo expirou antes de agir** (o cron já retirou): ao abrir, banner neutro "O prazo para
  confirmar terminou e sua candidatura saiu desta vaga." (sem ação) — estado 4.6.
- **Erro de rede:** botão volta ao estado normal + toast "Não foi possível agora. Tente de novo."

---

## 3. Layout

### Surface A — Mobile (≥360px)

Passo 1 — Form (idêntico a 046, pré-preenchido):

```
+--------------------------------+
| ← Editar vaga                  |
+--------------------------------+
| Função                         |
| [ Garçom               ▼ ]     |
| Quando                         |
| Início [12/06/2026][18:00]     |
| Fim    [12/06/2026][23:00]     |
| ⏱ A vaga dura 5h.              |
| Pagamento e posições           |
| Valor  [R$ 150,00]             |
| Quantas pessoas?  [-] 2 [+]    |
| Observações                    |
| [ Levar avental preto. ]       |
+--------------------------------+
| [   Revisar alteração   ]      |  ← mostarda, 48dp
+--------------------------------+
```

Passo 2 — Confirmação (bottom sheet em mobile / dialog em desktop):

```
+--------------------------------+
| Revisar alteração              |
| Confira o que muda antes de    |
| salvar.                        |
|                                |
| ┌ O que muda ─────────────┐   |
| │ Valor                    │   |
| │  R$ 120,00 → R$ 150,00   │   |  ← diff.row
| │ Início                   │   |
| │  18:00 → 19:00           │   |
| └──────────────────────────┘   |
|                                |
| ⚠ 3 candidatos pendentes vão   |  ← banner.warning
|   ser avisados e têm até 24h   |
|   (ou até o turno começar)     |
|   para confirmar. Quem não     |
|   confirmar sai automatic.     |
|                                |
| [   Confirmar alteração   ]    |  ← mostarda
| [     Voltar e ajustar    ]    |  ← text
+--------------------------------+
```

- Componentes do DS: `cadastro.section`, `cadastro.textfield`, `cadastro.errortext`,
  `button.primary`, `button.text`, `surface.card`, `diff.row`, `banner.warning`, `banner.error`.
- Alvo de toque ≥48dp em todos os botões e no overflow "Editar" do card de 047.

### Surface A — Desktop (≥1024px)

- Form centralizado, `maxWidth: 640` (igual 046). Passo 2 vira **`AlertDialog`** centrado (não
  bottom sheet), `maxWidth: 520`, com o diff e o aviso; ações no rodapé à direita
  ("Voltar e ajustar" `text` + "Confirmar alteração" `primary`).

### Surface B — Mobile (≥360px) — detalhe (049) com revisão

```
+--------------------------------+
| ← Detalhe da vaga              |
+--------------------------------+
| ⚠ Esta vaga foi editada        |  ← banner.revisao (warning)
|   Confirme até qui, 12/06      |
|   18:00 — senão sua            |
|   candidatura sai sozinha.     |
|                                |
|   O que mudou:                 |
|   Valor  R$120,00 → R$150,00   |  ← diff.row
|   Início 18:00 → 19:00         |
|                                |
|   [   Manter candidatura   ]   |  ← verde, 48dp
|   [        Retirar         ]   |  ← outline
+--------------------------------+
| Garçom · Bar do Zé             |
| (resto do detalhe 049 normal)  |
+--------------------------------+
```

- O banner fica **acima** do conteúdo do detalhe (primeira dobra) — é a tarefa do momento (#1).
- No **card do feed** (048, filtro "Candidatadas"): um selo `badge.status` mostarda "Vaga editada
  — confirme" no canto do card; tocar o card abre o detalhe.

### Surface B — Desktop (≥1024px)

- Mesmo banner no topo da coluna de conteúdo do detalhe; as duas ações lado a lado.

---

## 4. Estados

### 4.1. Caminho feliz
Coberto pelos sketches de §3. Microcopy completo em §5.

### 4.2. Loading
- **A (load do form):** skeleton dos campos (barras) — **não** spinner em tela branca (#6). Reusa
  o loading de 046.
- **A (confirmar):** botão "Confirmar alteração" entra em estado `loading` (spinner inline), os
  dois botões desabilitam.
- **B (manter/retirar):** botão acionado entra em `loading` inline; otimismo visual após sucesso.

### 4.3. Vazio / "nada mudou"
- **A:** se o contratante abre "Revisar alteração" sem ter mudado nenhum campo material, **não**
  abre o passo 2 — mostra inline, abaixo do CTA, "Você ainda não alterou nada." e o botão fica
  desabilitado até haver mudança. (Evita commit no-op.)

### 4.4. Erro
- **A — validação de campo** (data_fim ≤ data_inicio, valor ≤ 0, função vazia): erro **no campo**
  (mesma regra de 046), antes de chegar ao passo 2.
- **A — rede/5xx no confirmar:** `banner.error` no passo 2: "Não foi possível salvar agora.
  Verifique sua conexão e tente de novo." + "Tentar de novo". Rascunho preservado.
- **A — 409 (vaga não editável):** ao confirmar, se a vaga não está mais `aberta` →
  `banner.error`: "Esta vaga não pode mais ser editada (ela foi fechada ou cancelada)." + "Ver a
  vaga". Sem retry.
- **B — rede/5xx em manter/retirar:** toast "Não foi possível agora. Tente de novo." + botão
  volta ao normal (sem mudar estado visual).

### 4.5. Sem permissão
- **A:** profissional na rota `/editar` → "Esta área é do contratante" + "Voltar ao início"
  (reusa o `_SemPermissaoView` de 046). Contratante **não-dono** → mesma saída (o back devolve 403).
- **B:** as ações de manter/retirar só aparecem para o **dono** da candidatura
  `pendente_revisao_apos_edicao`; ninguém mais vê o banner.

### 4.6. Parcial / degradado / prazo expirado
- **B — prazo expirado:** o profissional abre o detalhe **depois** de o cron já ter retirado a
  candidatura. Não há banner de ação; mostra faixa neutra (`info`): "O prazo para confirmar
  terminou e sua candidatura saiu desta vaga." Estado factual, sem culpa.
- **A — contagem de candidatos indisponível** (degradação do GET de edição): o passo 2 ainda
  mostra o diff, mas o aviso cai para a forma genérica "Os candidatos pendentes serão avisados…"
  (sem número). Nunca bloqueia a edição por causa da contagem.

### 4.7. Primeira vez vs recorrente
- Não há onboarding dedicado; o diff é autoexplicativo. (Sem tutorial — #1.)

---

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| **A — Título da tela** | Editar vaga |
| A — CTA primário (form) | Revisar alteração |
| A — Inline "nada mudou" | Você ainda não alterou nada. |
| A — Título do passo 2 | Revisar alteração |
| A — Subtítulo do passo 2 | Confira o que muda antes de salvar. |
| A — Cabeçalho do diff | O que muda |
| A — Aviso com candidatos (plural) | {n} candidatos pendentes vão ser avisados e têm até 24h (ou até o turno começar) para confirmar. Quem não confirmar sai automaticamente. |
| A — Aviso com candidatos (singular) | 1 candidato pendente vai ser avisado e tem até 24h (ou até o turno começar) para confirmar. Quem não confirmar sai automaticamente. |
| A — Aviso sem candidatos | Ninguém se candidatou ainda — a alteração entra na hora, sem avisos. |
| A — Aviso degradado (sem número) | Os candidatos pendentes serão avisados e terão até 24h (ou até o turno começar) para confirmar. |
| A — CTA confirmar | Confirmar alteração |
| A — CTA voltar | Voltar e ajustar |
| A — Toast sucesso (com candidatos) | Vaga atualizada — {n} candidato(s) foram avisados. |
| A — Toast sucesso (sem candidatos) | Vaga atualizada. |
| A — Erro rede (passo 2) | Não foi possível salvar agora. Verifique sua conexão e tente de novo. |
| A — Erro 409 | Esta vaga não pode mais ser editada (ela foi fechada ou cancelada). |
| A — CTA erro 409 | Ver a vaga |
| A — Sem permissão (título) | Esta área é do contratante |
| A — Sem permissão (corpo) | Editar vagas é uma ação de quem contrata. Sua conta é de profissional. |
| **B — Banner título** | Esta vaga foi editada |
| B — Banner prazo (data) | Confirme até {dia}, {data} às {hora} — senão sua candidatura sai sozinha. |
| B — Banner "o que mudou" (rótulo) | O que mudou |
| B — CTA manter | Manter candidatura |
| B — CTA retirar | Retirar |
| B — Confirmação de retirar (título) | Retirar candidatura? |
| B — Confirmação de retirar (corpo) | Você sai desta vaga e não recebe mais novidades dela. |
| B — Confirmação de retirar (CTA) | Sim, retirar |
| B — Confirmação de retirar (voltar) | Voltar |
| B — Toast manteve | Candidatura mantida. |
| B — Toast retirou | Candidatura retirada. |
| B — Erro manter/retirar | Não foi possível agora. Tente de novo. |
| B — Prazo expirado (faixa) | O prazo para confirmar terminou e sua candidatura saiu desta vaga. |
| B — Selo no card do feed | Vaga editada — confirme |
| Rótulos de campo do diff | Função / Início / Fim / Valor / Quantas pessoas / Observações |

Vocabulário: glossário do PO ("Vaga", "Candidatura", "Contratante", "Profissional", "Turno").
Horário 24h, pt-BR (DDR-002 — nunca AM/PM).

## 6. Acessibilidade

- **Diff sem depender de cor (#5):** cada `diff.row` carrega rótulo + valor antigo + seta "→" +
  valor novo em texto. `Semantics` lê "Valor: de R$ 120,00 para R$ 150,00". O valor antigo pode ter
  `decoration: lineThrough` mas a semântica não depende disso.
- **Foco inicial:** A passo 2 → foco no título do sheet/dialog; B → foco no banner (live region) ao
  entrar em revisão.
- **Live regions:** toasts de sucesso/erro e o banner de revisão usam `Semantics(liveRegion: true)`.
- **Botões destrutivos:** "Retirar" tem confirmação (dialog) — não é ação de um toque sem rede de
  segurança; foco inicial do dialog no "Voltar" (saída segura).
- **Alvos de toque ≥48dp:** todos os CTAs, o overflow "Editar" do card de 047, e os botões do
  banner. ✅
- **Contraste:** mostarda CTA (4.5:1 ✅), verde CTA (7.4:1 ✅), warnSoft com texto forte (✅),
  texto mudo do valor antigo ≥ 4.5:1 (usa `textMuted`, não cinza-claro). ✅

## 7. Identificadores estáveis sugeridos para teste

| Elemento | Identificador lógico |
|---|---|
| **A** Tela editar | `editar-vaga-screen` |
| A CTA "Revisar alteração" | `editar-vaga-revisar-btn` |
| A Inline "nada mudou" | `editar-vaga-nada-mudou` |
| A Passo 2 (sheet/dialog) | `editar-vaga-confirmar-sheet` |
| A Linha de diff (por campo) | `editar-vaga-diff-{campo}` |
| A Aviso de candidatos | `editar-vaga-aviso-candidatos` |
| A CTA "Confirmar alteração" | `editar-vaga-confirmar-btn` |
| A CTA "Voltar e ajustar" | `editar-vaga-voltar-btn` |
| A Banner erro 409 | `editar-vaga-erro-409` |
| A Overflow "Editar" no card 047 | `minhas-vagas-editar-{id}` |
| **B** Banner de revisão (detalhe) | `vaga-detalhe-revisao-banner` |
| B Linha de diff (por campo) | `vaga-detalhe-revisao-diff-{campo}` |
| B CTA "Manter candidatura" | `vaga-detalhe-manter-btn` |
| B CTA "Retirar" | `vaga-detalhe-retirar-btn` |
| B Faixa "prazo expirado" | `vaga-detalhe-revisao-expirada` |
| B Selo no card do feed | `feed-card-revisao-{id}` |

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `diff.row` (linha "campo: antigo → novo") | 1º padrão de diff do app; reusa `surface.card` + tokens de texto forte/mudo + ícone de seta. Não inventa token nem componente custom; é composição. | Se reaparecer (ex.: histórico de versões da vaga), promover a componente no DS. Por ora, exceção documentada. |
| `banner.revisao` | Faixa de revisão pós-edição = `banner.warning` existente + bloco de prazo + 2 ações. Variante de uso, não componente novo. | Não — é uso de `banner.warning`. |
| Selo "Vaga editada — confirme" no card do feed | Reusa `badge.status` no acento mostarda sobre card do profissional (cor de aviso, não de papel). | Não. |

## 9. Protótipo HTML fiel (validação humana)

- **Localização:** `SCREEN-STORY-052-editar-vaga-e-diff/index.html` (sibling deste spec).
- **Cobertura:** seletor de **superfície** (Contratante / Profissional) + seletor de **estado**
  (form, confirmação com candidatos, confirmação sem candidatos, nada-mudou, erro-rede, erro-409,
  revisão, retirar-confirm, prazo-expirado) + seletor de **viewport** (mobile / desktop).
- **Fidelidade:** tokens reais do DS (mostarda/verde/warnSoft, raios, espaçamento 8pt). Microcopy =
  exatamente a tabela §5. Horário 24h.
- **Restrições:** HTML/CSS/JS vanilla, sem rede, abre clicando. Mocks inline. Cabeçalho declara
  "protótipo de validação, não código de produção".

### Checklist antes de `ready`
- [x] `index.html` abre sem erro.
- [x] Todos os estados de §4 acessíveis.
- [x] Mobile + desktop navegáveis.
- [x] Microcopy bate com §5.
- [x] Identificadores de §7 presentes como `data-testid`.
- [x] Tokens reais do DS.
- [x] Apresentado ao humano (Alexandro) no browser e aprovado em chat (2026-06-02).

## 10. Dependências e premissas

- **API esperada (contrato definido pela estória + IDR do Programador):**
  - `GET /api/vagas/{id}/editar` (dono) → campos materiais atuais + `candidatos_em_revisao`
    (pendente + pendente_revisao). Carrega o form e alimenta o número do aviso.
  - `PATCH /api/vagas/{id}` (dono) → resposta com `diff` + `candidatos_notificados` (CA-1/CA-3).
  - `POST /api/candidaturas/{id}/confirmar-apos-edicao` (CA-7) e
    `POST /api/candidaturas/{id}/retirar-apos-edicao` (CA-8).
  - `GET /api/vagas/{id}/detalhe` (049) **estendido**: quando a candidatura do profissional está
    `pendente_revisao_apos_edicao`, inclui bloco `revisao { prazo_em, diff[] }` para o banner B.
  - Feed (048) já devolve a candidatura por vaga no filtro "Candidatadas"; o selo lê o estado
    `pendente_revisao_apos_edicao`.
- **Premissas:** o `diff` (antes/depois por campo) é calculado no servidor (comparando o snapshot
  `vaga_versoes` que o profissional viu contra a versão atual — CA-3) e devolvido pronto; a UI não
  recalcula valores nem decide o que é material. O prazo `prazo_em` é o persistido
  (`revisao_prazo_em`) — 24h ou início do turno, o que vier antes (PDR-009).
- O diff client-side do **preview do contratante** (passo 2) é apenas visual (a UI tem antes/depois
  do próprio form); a verdade material é do servidor no PATCH.

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-02 | criação + protótipo v1 | claude-opus-4-8 (designer) | spec inicial das 2 superfícies + protótipo HTML com todos os estados |
| 2026-06-02 | validação humana | Alexandro | protótipo aprovado no browser — "pode implementar" |
