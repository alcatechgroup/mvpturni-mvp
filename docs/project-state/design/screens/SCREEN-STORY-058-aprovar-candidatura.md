---
id: SCREEN-STORY-058-aprovar-candidatura
story: STORY-058-aceitar-candidatura-backoffice-aceite-eletronico-preauth
epic: EPIC-003-aceite-pin-e-pix
status: shipped              # draft | ready | in_implementation | shipped | superseded
created_at: 2026-06-04
updated_at: 2026-06-05
owner_designer: claude-opus-4-8
related_ddrs: [DDR-001, DDR-002]
ds_components_used: [surface.card, dialog, snackbar, button.primary, button.secondary, button.text, badge.status, habitualidade.badge, match.scorechip]
exceptions_to_ds: [dialog.destaque-financeiro (tabela valor/taxa/total dentro do dialog de confirmação — 1º uso; candidata a promoção quando STORY-060 reusar no detalhe do turno)]
viewports: [mobile, desktop]
prototype_path: SCREEN-STORY-058-aprovar-candidatura/index.html
prototype_last_validated_at: 2026-06-05   # validado em homolog (rc.70) + aprovado por Alexandro em chat
---

# Spec de tela — SCREEN-STORY-058 — Aceitar candidatura (painel de candidatos)

> Referência: estória `STORY-058`. CAs e contexto vêm de lá — **não duplico**.
> Esta spec é um **delta sobre `SCREEN-STORY-051`** (painel de candidatos): a tela, a lista, os
> cards, o breakdown e os estados de fetch **não mudam**. O que muda: o botão **"Aceitar
> candidatura"** sai de desabilitado (promessa do EPIC-003) e vira a **ação que abre o turno**,
> com 3 diálogos novos + estados de envio/desfecho. "Remover candidato" **continua desabilitado**
> (recusa é Lacuna do MVP).
> Decisão do PO (2026-06-04, chat): quem aprova é o **contratante no WebApp** — não o admin no
> Backoffice (CA-1 corrigido na estória).
> Fundação: DDR-001 (acento mostarda do contratante; warning para habitualidade; error só para
> erro real), DDR-002 (pt-BR, 24h). Regra de negócio: PDR-002 (habitualidade), PDR-004 (taxa 15%
> — contratante vê valor/taxa/total separados, `domain/pagamento.md` §visibilidade), PDR-017
> (pagamento simulado via fake — a UI fala "pré-autorização do pagamento" sem citar provedor).
> Princípios que guiaram: **#1** (um diálogo por decisão; nada de wizard), **#3** (tom sério —
> aceite é ato contratual; sucesso celebra com discrição), **#5** (bloqueio/alerta nunca só por
> cor; razão sempre em texto), **#7** (todos os desfechos desenhados: sucesso, bloqueio PF,
> override PJ, idempotência, vaga fechada, erro de rede).

---

## 1. Objetivo

Transformar o "Aceitar candidatura" numa decisão **consciente e à prova de erro** para um gestor
não-técnico: (a) confirmar mostrando **o que ele paga** (valor + taxa + total — PDR-004) e que um
**contrato do turno** será emitido; (b) quando a regra de habitualidade barrar (PF 3ª), explicar
o porquê em linguagem simples, sem beco sem saída; (c) quando exigir override (PJ 3ª), pedir o
aceite de risco **explícito** com o peso certo (compliance.md §habitualidade); (d) nunca cobrar
dobrado num clique duplo (o botão trava em voo; o servidor é idempotente).

## 2. Fluxo

```
[ painel de candidatos (SCREEN-051) ]
   │ tap "Aceitar candidatura" (agora habilitado)
   ▼
[ D1 — dialog Confirmar aceite ]──"Voltar"──► (fecha, nada acontece)
   │ tap "Confirmar aceite"
   ▼ POST /api/candidaturas/{id}/aprovar        (botão em loading; ações travadas)
   │
   ├─ 201 turno criado ────────────────► [ snackbar sucesso ] + lista recarrega
   │                                      (candidato sai da lista — virou turno;
   │                                       vaga cheia → contexto/estado da 051)
   ├─ 422 habitualidade_bloqueio (PF) ──► [ D2 — dialog Bloqueio PF ] — só "Entendi"
   ├─ 422 requer_override (PJ 3ª) ──────► [ D3 — dialog Aceite de risco PJ ]
   │                                        │ tap "Assumo o risco e aceito"
   │                                        ▼ POST …/aprovar { override: true } → desfechos acima
   ├─ 409 já aprovada (idempotência) ───► [ snackbar "já foi aceita" ] + lista recarrega
   ├─ 422 vaga fechada/cancelada ───────► [ snackbar vaga indisponível ] + lista recarrega
   └─ rede / 5xx ───────────────────────► [ snackbar erro + Tentar de novo ]
```

- **Entrada:** o painel 051, caminho feliz (lista com candidatos `pendentes`).
- **Pré-aviso de habitualidade:** se o card já tem `habitualidade.badge` (MEI/PJ — CA-5 da 051),
  o D1 mostra a linha de atenção (§4.1) — o contratante não é surpreendido pelo D3.
- **Saída:** a tela permanece; a lista recarrega após qualquer desfecho que mude estado no
  servidor. Ver o turno criado é STORY-059/060 (o snackbar de sucesso antecipa isso em texto).

## 3. Layout

### D1 — Dialog "Confirmar aceite" (`AlertDialog`, mobile e desktop)

```
+--------------------------------------------------+
|  Aceitar candidatura                              |   título (titleLarge)
|                                                   |
|  Você está abrindo um turno com                   |
|  **Júlia Santos** — Garçom                        |   nome forte + função
|  Sex, 12/06 · 18:00–23:00                         |   data/hora pt-BR 24h (DDR-002)
|                                                   |
|  ┌──────────────────────────────────────────┐    |   dialog.destaque-financeiro (§8)
|  │ Profissional recebe          R$ 200,00    │    |   text.muted | número text.strong
|  │ Taxa Turni (15%)             R$ 30,00     │    |
|  │ ───────────────────────────────────────   │    |   divisor border.subtle
|  │ Total a pagar                R$ 230,00    │    |   linha forte (w800)
|  └──────────────────────────────────────────┘    |
|                                                   |
|  ⚠ Este profissional já tem 2 turnos com você     |   SÓ quando alerta_habitualidade
|    nesta semana. Vamos pedir sua confirmação      |   (pill warning soft, ícone+texto)
|    de risco no próximo passo.                     |
|                                                   |
|  Ao confirmar, o pagamento é pré-autorizado e o   |   corpo text.muted (bodyMedium)
|  contrato do turno é emitido e registrado.        |
|                                                   |
|              [ Voltar ]  [ Confirmar aceite ]     |   text + primary (mostarda)
+--------------------------------------------------+
```

- **Enviando:** "Confirmar aceite" vira spinner inline + label "Confirmando…"; os dois botões
  desabilitam; `barrierDismissible: false` durante o voo (anti clique-duplo — CA-5 na UI).
- Mobile: dialog ocupa largura padrão do Material (inset 40dp); desktop: max ~420px.

### D2 — Dialog "Aceite bloqueado" (PF 3ª — CA-3)

```
+--------------------------------------------------+
|  🛡  Aceite bloqueado                             |   ícone shield_outlined + título
|                                                   |
|  Este profissional é PF e já tem 2 alocações      |
|  nesta semana neste estabelecimento.              |
|                                                   |
|  Para proteger a relação de trabalho eventual,    |
|  a plataforma bloqueia a 3ª alocação semanal de   |
|  profissionais PF — sem exceção.                  |
|                                                   |
|  Você pode aceitá-lo a partir da próxima semana,  |
|  ou escolher outro candidato.                     |   próximo passo claro (#1)
|                                                   |
|                                    [ Entendi ]    |   button.primary
+--------------------------------------------------+
```

- **Não é erro do usuário** → ícone de proteção (não ✕ vermelho); superfície normal; o tom é
  "a plataforma te protegeu", não "você falhou". Cor de destaque: `warning.soft` no ícone.

### D3 — Dialog "Aceite de risco" (PJ 3ª — CA-4)

```
+--------------------------------------------------+
|  ⚠  3ª alocação na mesma semana                   |   ícone warning + título
|                                                   |
|  Este profissional já realizou 2 turnos com       |   compliance.md §habitualidade
|  você nesta semana. Sinais de habitualidade.      |   (copy canônico do PO)
|                                                   |
|  Você pode prosseguir, mas isso fica registrado   |
|  como aceite consciente de risco no contrato do   |
|  turno. Considere se faz sentido continuar.       |
|                                                   |
|         [ Voltar ]  [ Assumo o risco e aceito ]   |   text + primary
+--------------------------------------------------+
```

- O CTA usa o **verbo do registro jurídico** (compliance.md): "Assumo o risco e aceito" —
  exatamente o que fica carimbado no aceite eletrônico (cláusula 10). Sem eufemismo.
- Enviando: mesmo comportamento do D1 (spinner inline, botões travados).
- O D3 **substitui** o D1 quando o servidor responde `requer_override` — não empilha dialogs.

### Snackbars (desfechos rápidos)

| Desfecho | Estilo | Texto |
|---|---|---|
| Sucesso (201) | neutro com check `success` | Turno confirmado. O contrato foi registrado e o pagamento está sendo pré-autorizado. |
| Já aceita (409) | neutro | Esta candidatura já foi aceita — o turno existe. |
| Vaga fechada (422) | neutro | Esta vaga não está mais aberta. A lista foi atualizada. |
| Erro rede/5xx | `error.soft` + ação | Não foi possível concluir o aceite. *(ação: Tentar de novo — reabre D1 com os mesmos dados)* |

Duração 6s (sucesso) / 4s (demais). Após sucesso/409/vaga fechada, a **lista recarrega** — o
candidato aprovado sai (a 051 lista só `pendentes`) e a contagem/contexto atualiza.

## 4. Estados (além dos herdados da 051)

1. **D1 padrão** — resumo + financeiro. 2. **D1 com pré-aviso** de habitualidade (PJ com badge).
3. **D1 enviando** (spinner, travado). 4. **D2 bloqueio PF**. 5. **D3 override PJ**.
6. **D3 enviando**. 7. **Snackbar sucesso + lista recarregada** (candidato saiu; se a vaga
fechou, a faixa de contexto reflete). 8. **Snackbar 409/vaga fechada**. 9. **Snackbar erro com
retry**. 10. **Botão do card em voo** — enquanto um aceite está em andamento, os botões "Aceitar"
de **todos** os cards desabilitam (uma decisão por vez; evita corrida de posições).

## 5. Microcopy completo

| Lugar | Texto |
|---|---|
| D1 — título | Aceitar candidatura |
| D1 — corpo (quem) | Você está abrindo um turno com **{nome}** — {função} |
| D1 — corpo (quando) | {Dia, dd/mm · HH:mm–HH:mm} |
| D1 — linha 1 | Profissional recebe → {R$ valor} |
| D1 — linha 2 | Taxa Turni (15%) → {R$ taxa} |
| D1 — linha 3 | Total a pagar → {R$ total} |
| D1 — pré-aviso (só PJ c/ badge) | Este profissional já tem 2 turnos com você nesta semana. Vamos pedir sua confirmação de risco no próximo passo. |
| D1 — nota legal | Ao confirmar, o pagamento é pré-autorizado e o contrato do turno é emitido e registrado. |
| D1 — CTA primário | Confirmar aceite |
| D1 — CTA secundário | Voltar |
| D1/D3 — CTA enviando | Confirmando… |
| D2 — título | Aceite bloqueado |
| D2 — corpo 1 | Este profissional é PF e já tem 2 alocações nesta semana neste estabelecimento. |
| D2 — corpo 2 | Para proteger a relação de trabalho eventual, a plataforma bloqueia a 3ª alocação semanal de profissionais PF — sem exceção. |
| D2 — corpo 3 | Você pode aceitá-lo a partir da próxima semana, ou escolher outro candidato. |
| D2 — CTA | Entendi |
| D3 — título | 3ª alocação na mesma semana |
| D3 — corpo 1 | Este profissional já realizou 2 turnos com você nesta semana. Sinais de habitualidade. |
| D3 — corpo 2 | Você pode prosseguir, mas isso fica registrado como aceite consciente de risco no contrato do turno. Considere se faz sentido continuar. |
| D3 — CTA primário | Assumo o risco e aceito |
| D3 — CTA secundário | Voltar |
| Snackbar — sucesso | Turno confirmado. O contrato foi registrado e o pagamento está sendo pré-autorizado. |
| Snackbar — 409 | Esta candidatura já foi aceita — o turno existe. |
| Snackbar — vaga fechada | Esta vaga não está mais aberta. A lista foi atualizada. |
| Snackbar — erro | Não foi possível concluir o aceite. |
| Snackbar — erro (ação) | Tentar de novo |

Valores em R$ pt-BR (vírgula decimal). Datas 24h (DDR-002). Sem "Ops!", sem emoji no copy —
ícones são de estado. A palavra **"contrato do turno"** (não "aceite eletrônico") é a voz do
usuário; o termo técnico vive no domínio. O nome do provedor de pagamento **não aparece**
(PDR-017 — o banner global de homolog é da STORY-075, fora desta spec).

## 6. Acessibilidade

- Dialogs Material (`AlertDialog`): foco entra no dialog, `Esc`/barrier fecham **só quando não
  está enviando**; foco retorna ao botão de origem ao fechar.
- D2/D3: ícone com `Semantics(label:)` — "Bloqueado por regra de proteção" / "Atenção: aceite de
  risco". O conteúdo nunca depende só da cor (texto integral).
- Botões enviando: `Semantics(enabled: false)` + label "Confirmando aceite".
- Snackbars: anunciados (live region nativa do `SnackBar`); o de erro tem ação focável.
- Tabela financeira: `MergeSemantics` por linha → "Profissional recebe, duzentos reais".
- Contraste: tokens DDR-001 já auditados (mostarda `#9A6E25` em CTA com branco = 4.5:1; corpo
  `text.muted #42504A`; warning soft `#FBEED1` com tinta `#6E4E12`).
- Alvos ≥48dp em todos os CTAs dos dialogs.

## 7. Identificadores estáveis sugeridos

| Elemento | Identificador lógico |
|---|---|
| Botão aceitar (card — existente, agora habilitado) | `candidato-card-{id}-aceitar-btn` |
| D1 — dialog | `aprovar-dialog-confirmar` |
| D1 — bloco financeiro | `aprovar-dialog-financeiro` |
| D1 — pré-aviso habitualidade | `aprovar-dialog-pre-aviso-habitualidade` |
| D1 — CTA confirmar | `aprovar-dialog-confirmar-btn` |
| D1 — CTA voltar | `aprovar-dialog-voltar-btn` |
| D2 — dialog bloqueio PF | `aprovar-dialog-bloqueio-pf` |
| D2 — CTA entendi | `aprovar-dialog-bloqueio-pf-entendi-btn` |
| D3 — dialog override PJ | `aprovar-dialog-override-pj` |
| D3 — CTA assumir risco | `aprovar-dialog-override-pj-aceitar-btn` |
| D3 — CTA voltar | `aprovar-dialog-override-pj-voltar-btn` |
| Snackbar sucesso | `aprovar-snackbar-sucesso` |
| Snackbar erro | `aprovar-snackbar-erro` |

## 8. Exceções ao Design System

| O que diverge | Por quê | Vira DDR? |
|---|---|---|
| `dialog.destaque-financeiro` — tabela de 3 linhas (recebe/taxa/total) dentro do dialog, com total em peso forte | PDR-004 manda o contratante ver os 3 componentes separados **no momento da decisão**. 1º uso. | Candidata — promover quando STORY-060 (detalhe do turno) reusar o mesmo bloco. |
| D2 com ícone de **proteção** (shield) em vez de erro | Bloqueio PF não é falha do usuário; é a plataforma cumprindo a promessa de governança (PDR-002). Vermelho mentiria a semântica. | Não — decisão local coerente com a regra de contexto do DDR-001 (warning ≠ error). |

## 9. Protótipo HTML fiel

- **Localização:** `SCREEN-STORY-058-aprovar-candidatura/index.html`.
- **Cobertura:** seletor de viewport (mobile/desktop) + seletor de estado: `d1` (confirmação),
  `d1-aviso` (com pré-aviso PJ), `d1-enviando`, `d2-bloqueio-pf`, `d3-override-pj`,
  `sucesso` (snackbar + lista sem o candidato), `erro` (snackbar com retry).
- **Fidelidade:** tokens reais (mostarda/warning/neutros §tokens.md), microcopy §5 palavra por
  palavra, identificadores §7 como `data-testid`, card do painel 051 reproduzido como contexto
  de fundo.
- HTML/CSS/JS vanilla, sem rede; comentário "protótipo de validação, não código de produção".

## 10. Dependências e premissas

- **Contrato do endpoint (estória CA-1..CA-5):** `POST /api/candidaturas/{id}/aprovar`
  body `{ override?: bool }` →
  - `201 { turno: { id, status: "confirmado", valor, taxa_turni, total_contratante } }`
  - `422 { erro: "habitualidade_bloqueio", mensagem }` (PF 3ª)
  - `422 { erro: "requer_override", mensagem }` (PJ 3ª sem override)
  - `422 { erro: "vaga_fechada" | "candidatura_invalida", mensagem }`
  - `409 { erro: "ja_aprovada", turno_id }` (idempotência de clique duplo entre sessões)
  - `403/404` herdam o tratamento da 051.
- Valores (valor/taxa/total) para o D1 vêm do **payload do painel** (CA-1 da 051 ganha os campos
  da vaga) — o Programador decide a fonte exata; o que a spec fixa é **o que** aparece.
- "Remover candidato" segue desabilitado (Lacuna MVP). O lado do profissional (ver a razão do
  bloqueio) foi **adiado para STORY-059/060** (decisão PO 2026-06-04).

## 11. Histórico de mudanças

| Data | Mudança | Quem | Motivo |
|---|---|---|---|
| 2026-06-04 | criação (delta sobre SCREEN-051: D1 confirmação c/ financeiro PDR-004, D2 bloqueio PF, D3 override PJ, snackbars de desfecho, anti clique-duplo) | claude-opus-4-8 (designer) | STORY-058; decisão PO em chat moveu a aprovação para o contratante no WebApp |
| 2026-06-05 | validação humana — Alexandro percorreu os 3 cenários em homolog (rc.70) e aprovou em chat; `status: shipped` | Alexandro | D1/D2/D3 + snackbars conferidos no app real |
