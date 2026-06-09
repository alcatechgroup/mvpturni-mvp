# Fluxo — Avaliação recíproca e fechamento do ciclo

> Base: **PDR-005** (avaliação obrigatória e bloqueante), **ADR-019** (modelo + eventos + motor + gate), `domain/niveis-e-score.md`, `domain/turno.md` §Avaliação.
> Modelo canônico de dados: tabela `avaliacoes` (uma linha por direção/turno) — **ADR-019 Decisão 1** substitui o esboço jsonb de `turno.md`.

## Quem dispara

Profissional **e** contratante, cada um do seu lado, após um turno chegar a estado avaliável.

## Pré-condições

- Existe um turno em `finalizado` ou `finalizado_ajustado` (estados avaliáveis — ADR-015).
- O turno tem dois papéis: `profissional_id` e `contratante_id`.
- A avaliação é **recíproca**: cada lado avalia o outro, de forma independente (um lado pode avaliar antes do outro).

## Conceitos

- **Direção da avaliação** (`avaliacoes.direcao`):
  - `contratante_para_profissional` — o contratante avalia o profissional.
  - `profissional_para_contratante` — o profissional avalia o contratante.
- **Pendência** (derivada — ADR-019 Decisão 2): um turno avaliável está *pendente para uma direção* enquanto **não existir** linha em `avaliacoes` para aquele `(turno_id, direcao)`. Não há registro de pendência; é uma consulta sobre o estado.
- **Avaliado / autor**: quem recebe / quem escreve a avaliação.
- **Depoimento**: avaliação com `comentario` não-vazio, exibida no perfil público do **avaliado**.

## Caminho feliz (passo a passo)

1. **Turno finaliza.** A transição `aguardando_checkout → finalizado` (ADR-015) emite o evento `TurnoFinalizado`. Além do ciclo financeiro (captura + Pix), um listener cria a **notificação "avalie seu turno"** (in-app + e-mail) para **os dois lados**. A partir daqui, o turno está pendente nas duas direções.
2. **Cada lado é levado a avaliar.** Pela notificação/deep-link ou ao tentar uma nova ação (ver Gate), o usuário chega à tela de avaliação do turno: **estrelas (1–5) obrigatórias** + **comentário (opcional)**.
3. **Envio da avaliação.** O sistema insere uma linha em `avaliacoes` (`turno_id`, `autor_id`, `avaliado_id`, `direcao`, `estrelas`, `comentario?`). O `UNIQUE (turno_id, direcao)` garante **uma avaliação por direção por turno** — reenvio é rejeitado.
4. **Reputação atualiza (≤1s).** Dentro da mesma transação, `AvaliacaoRegistrada` dispara o `MotorReputacao`, que **recomputa** a reputação do **avaliado**:
   - **Score** = média das estrelas recebidas (exibido com 1 casa, ex. 4.9★). Vale para os dois papéis (reciprocidade).
   - **XP** (só profissional) = `30 × turnos` + bônus por estrela (5★ +10, 4★ +3, 3★ 0, 1–2★ −5). Pode ficar negativo localmente.
   - **Nível** (só profissional) sobe automaticamente ao cruzar 500 / 1000 / 3000, e **nunca rebaixa** (high-water-mark).
5. **Reputação visível.** O perfil público do avaliado reflete o novo score/nível e, se houve comentário, o novo depoimento (os N mais recentes — quantidade/visibilidade exatas em DDR-004 / STORY-084).
6. **Ciclo fechado.** Quando os **dois** lados avaliaram, o turno não tem mais pendência; nenhum gate o bloqueia.

## Como o gate se manifesta (PDR-005 — ADR-019 Decisão 5)

O gate bloqueia a **ação**, não a **visibilidade**: o feed segue visível ao profissional; o que é barrado é iniciar nova ação com pendência.

- **Profissional tenta se candidatar** com avaliação pendente → **bloqueado**. Resposta: motivo `gate_avaliacao`, mensagem pt-BR ("Avalie seu último turno para se candidatar.") e o `turno_id` do turno pendente mais antigo para o deep-link à tela de avaliação. Aplicado em `CriarCandidaturaService` (já ligado; STORY-086 enche a query).
- **Contratante tenta publicar nova vaga** com avaliação pendente → **bloqueado**, simétrico: mensagem clara + `turno_id` para deep-link. Aplicado em `PublicarVagaService` (STORY-086 liga). Editar/cancelar vaga existente **não** é bloqueado — o gate é sobre *publicar nova*.
- **Fail-secure:** em qualquer ambiguidade, o gate bloqueia. Sem vazamento entre papéis: cada lado é avaliado pela pendência do **seu** papel e da **sua** direção.

## Estados e transições do fluxo (por direção, por turno)

```
turno finalizado/finalizado_ajustado
        │
        ▼
 [PENDENTE]  ──(usuário tenta nova ação)──►  AÇÃO BLOQUEADA (gate_avaliacao + turno_id)
   │  │                                              │
   │  └──────────────────────────────────────────────┘ (volta a avaliar)
   │
   ▼ (envia estrelas obrigatórias + comentário opcional → INSERT avaliacoes)
 [AVALIADO]  ──► AvaliacaoRegistrada ──► MotorReputacao recomputa (score/XP/nível) ──► reputação visível
        (idempotente: reprocesso produz o mesmo resultado; nível nunca rebaixa)
```

Cada direção é independente: um turno pode estar `AVALIADO` numa direção e `PENDENTE` na outra. O ciclo do turno fecha quando ambas as direções estão `AVALIADO`.

## Mensagens-chave (pt-BR — copy final é do Designer)

| Evento | Canal | Mensagem (referência) |
|---|---|---|
| Turno finalizado | in-app + e-mail | "Seu turno foi finalizado. Avalie o profissional/contratante para continuar." |
| Tentou candidatar pendente | bloqueio (UI) | "Avalie seu último turno para se candidatar." + link ao turno |
| Tentou publicar vaga pendente | bloqueio (UI) | "Avalie seu último turno para publicar uma nova vaga." + link ao turno |
| Avaliação recebida | in-app | "Você recebeu uma nova avaliação." |
| Subiu de nível | in-app | "Parabéns! Você alcançou o nível {Confiável/Destaque/Elite}." |

## Pós-condições

- Linha(s) em `avaliacoes` para o turno; no máximo uma por direção.
- `profissional_profiles` (score, xp, nível, turnos_realizados) e/ou `contratante_profiles` (score) do avaliado recomputados.
- Pendência some na direção avaliada; gate correspondente deixa de bloquear.
- Depoimentos (comentários) disponíveis para o perfil público (visibilidade conforme DDR-004).

## Fora deste fluxo (ver outros documentos)

- **Visibilidade e layout** de depoimentos/score/nível no perfil — DDR-004 / STORY-084 (Designer).
- **Motor de penalidade** de cancelamento/no-show (XP negativo por esses eventos) — PDR-007, fora do MVP (placeholder).
- **Decay** de score/XP no tempo — fora do MVP.
- **Moderação** de avaliação abusiva — admin caso-a-caso, sem UI (fora do MVP).
- **Disputa** (`em_disputa → finalizado_ajustado`) — EPIC-005; quando entrar, reusa este mesmo fluxo (estado também avaliável).

## Decisões de referência

- **PDR-005** — avaliação recíproca obrigatória e bloqueante.
- **ADR-019** — tabela `avaliacoes`, pendência derivada, eventos `TurnoFinalizado`/`AvaliacaoRegistrada`, motor por recomputação idempotente + nível high-water-mark, gate no service layer.
- **ADR-015** — estados avaliáveis (`finalizado`/`finalizado_ajustado`).
- **ADR-014** — o Match consome a reputação mantida por este fluxo.
- `domain/niveis-e-score.md`, `domain/turno.md`, `business-rules.md` (números).
