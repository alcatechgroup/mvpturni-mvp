---
id: DDR-004
title: Visibilidade de depoimentos, score com poucos dados e componentes de reputação
status: accepted   # proposed | accepted | superseded | rejected | deferred
created_at: 2026-06-09
decided_at: 2026-06-09
approved_by: Alexandro
supersedes: ~
superseded_by: ~
related_ddrs: [DDR-001, DDR-002, DDR-003]
related_adrs: [ADR-019, ADR-014, ADR-015]
related_pdrs: [PDR-005, PDR-007]
scope: reputação (perfil público, depoimentos, score, nível/XP) — transversal aos dois papéis
affects_screens: [SCREEN-STORY-084-avaliacao-e-perfil]
---

# DDR-004 — Visibilidade de depoimentos, score com poucos dados e componentes de reputação

## Contexto

A SPRINT-2026-W30 fecha o ciclo do turno com **avaliação recíproca obrigatória** (EPIC-004 / PDR-005). O Arquiteto já fixou modelo, eventos, motor e gate em **ADR-019** (tabela `avaliacoes` com `direcao`, pendência derivada, `MotorReputacao` por recomputação idempotente, nível high-water-mark, gate no service layer). O fluxo está em `flows/avaliacao-reciproca.md`. Resta a decisão de **design durável** que o domínio deixou explicitamente em aberto para DDR.

`domain/niveis-e-score.md` §Visibilidade diz, sobre o histórico de avaliações recebidas: *"anônimo? Nominal? Decidir em DDR de Design (sugestão: nome do estabelecimento visível, autor individual da avaliação não)"* e lista, como lacuna conhecida, *"Visibilidade individual vs. agregada dos depoimentos — decisão de DDR do Designer"*. Há ainda duas decisões correlatas que afetam a mesma superfície e precisam de uma régua única antes de qualquer tela (STORY-087/088): **como exibir o score quando há poucas avaliações** e **quais componentes de reputação entram no Design System**.

Documentos lidos: STORY-084 (CAs), ADR-019, `flows/avaliacao-reciproca.md`, `domain/niveis-e-score.md`, `domain/turno.md` §Avaliação, DDR-001 (tokens/perfil), DDR-003 (shell), `design/system/{tokens,components,patterns}.md`, `apps/webapp/lib/features/app/perfil_screen.dart` (Perfil atual — hoje só identidade + tema + Sair, reservado para receber score/depoimentos).

A decisão é **sensível** porque toca privacidade de pessoa física (LGPD) e a confiança do usuário não-técnico no número exibido. Por isso as duas escolhas-núcleo foram ratificadas pelo dono antes da formalização (ver §Aprovação humana).

## Forças (drivers)

- **Privacidade do autor / LGPD** (alto): o depoimento sobre um **contratante** é escrito por um **profissional — pessoa física**. Expor nome individual num perfil público cria risco de retaliação e desincentiva avaliação honesta. Já o depoimento sobre um **profissional** é escrito por um **contratante = estabelecimento (PJ / marca pública)** — nome de estabelecimento é informação pública por natureza.
- **Credibilidade do depoimento** (alto): "avaliação verificada" anônima nos dois lados protege privacidade mas enfraquece a confiança ("quem disse isso?"). Saber que veio de um estabelecimento real dá peso.
- **Confiança no score com amostra mínima** (alto): para o público não-técnico, "5.0★" com **1** avaliação engana tanto quanto "2.0★" destrói um bom profissional novo. O número precisa ser honesto sobre quão estabelecido ele é.
- **Princípio #1 (simplicidade radical)** (alto): o perfil não é dashboard. Mostra reputação legível de relance: score, nível, progresso, 3 depoimentos. O resto sob demanda.
- **Princípio #4 (padronização > criatividade)** (médio): rating, badge de nível, barra de XP e card de depoimento são padrões recorrentes — nascem no DS, não soltos na tela.
- **Princípio #7 (estados além do feliz)** (alto): perfil sem nenhuma avaliação, sem nenhum comentário (só estrelas), erro de carga — todos precisam de tratamento.
- **Reciprocidade (ADR-019 / domínio)** (médio): contratante **também** tem score e depoimentos; **não tem** nível/XP no MVP. A mesma régua serve aos dois, com a assimetria explícita do autor.
- **Restrição técnica (ADR-019)** (médio): score/nível/XP são **recomputados** e já moram em `profissional_profiles`/`contratante_profiles`; o front só lê. O comentário é o `comentario` da linha `avaliacoes`; o nome do estabelecimento e a função vêm do turno/contratante associados.

## Opções consideradas

A decisão tem **dois eixos** (identificação do autor; score com poucos dados). Para cada eixo, opções + status quo.

### Eixo 1 — Identificação do autor do depoimento

#### Opção A — Assimétrico (estabelecimento nominal / profissional anônimo)

Depoimento **sobre profissional** mostra **nome do estabelecimento + função do turno + data relativa**. Depoimento **sobre contratante** mostra **papel "Profissional" + função + data**, sem nome individual.

```
PERFIL DO PROFISSIONAL                    PERFIL DO CONTRATANTE
┌────────────────────────────────┐       ┌────────────────────────────────┐
│ ★★★★★                           │       │ ★★★★☆                           │
│ "Pontual e atencioso."          │       │ "Local organizado, pagou em dia."│
│ Restaurante Vista Mar · Garçom  │       │ Profissional · Garçom           │
│ há 3 dias                       │       │ há 1 semana                     │
└────────────────────────────────┘       └────────────────────────────────┘
```

- **Prós:** respeita a natureza jurídica de cada autor (PJ pública × pessoa física); protege o profissional de retaliação por avaliar o contratante honestamente (LGPD); mantém credibilidade onde ela é segura (estabelecimento nomeado).
- **Contras:** regra com duas faces — precisa estar clara no spec e no back; o contratante não vê "quem" o avaliou (aceitável — ele sabe pelo turno).

#### Opção B — Totalmente anônimo

Nenhum lado identifica o autor; só estrelas + comentário + função + data ("Avaliação verificada").

- **Prós:** privacidade máxima; regra única e simples.
- **Contras:** tira a credibilidade do depoimento sobre profissional (estabelecimento real importa para o contratante que vai contratar); iguala PJ e pessoa física sem motivo.

#### Opção C — Nominal nos dois lados

Mostra o nome de quem escreveu nos dois perfis (estabelecimento **e** nome do profissional).

- **Prós:** transparência máxima.
- **Contras:** ❌ expõe nome de pessoa física em perfil público (risco LGPD + retaliação); desincentiva honestidade do profissional ao avaliar o contratante. **Inaceitável** para o MVP.

### Eixo 2 — Score com poucas avaliações

#### Opção A — Selo "Novo na plataforma" até 3 avaliações

Com **< 3** avaliações recebidas, exibe o selo **"Novo na plataforma"** (+ contagem real se ≥1) em vez da média. A partir de **3**, exibe a média com 1 casa + contagem.

```
0 avaliações:  ⬡ Novo na plataforma
1 avaliação:   ⬡ Novo · 1 avaliação
3+:            4.9★ · 27 avaliações
```

- **Prós:** honesto sobre amostra mínima; não infla ("5.0★" com 1) nem destrói ("2.0★" com 1) um perfil novo; protege a confiança do não-técnico.
- **Contras:** introduz um estado/limiar a mais; o "3" é parâmetro de produto (documentado, ajustável).

#### Opção B — Sempre a média crua

Mostra a média desde a 1ª avaliação.

- **Contras:** ⚠️ "5.0★ · 1 avaliação" engana; uma 2★ inicial afunda um bom profissional. Reprova a força "confiança no score".

#### Status quo (ambos os eixos)

Não há tela de reputação hoje — `perfil_screen.dart` é placeholder declarado ("score e depoimentos chegam em épicos futuros"). Não decidir = bloquear STORY-087/088. Descartado por construção.

## Avaliação contra os princípios

| Princípio | Eixo1-A (assimétrico) | Eixo1-B (anônimo) | Eixo2-A (selo Novo) | Eixo2-B (média crua) |
|---|---|---|---|---|
| 1. Simplicidade radical | ✅ legível de relance | ✅ | ✅ um selo claro | ✅ |
| 2. Mobile-first com paridade | ✅ | ✅ | ✅ | ✅ |
| 3. Tom profissional Turni | ✅ sóbrio, sem gamificação ruidosa | ✅ | ✅ "Novo" discreto | ⚠️ número que mente é antiprofissional |
| 4. Padronização > criatividade | ✅ card de depoimento único c/ variante de autor | ✅ | ✅ variante de badge | ✅ |
| 5. Acessibilidade | ✅ estrelas têm texto+aria, não só cor | ✅ | ✅ selo tem texto | ✅ |
| 6. Performance percebida | ✅ skeleton no formato do conteúdo | ✅ | ✅ | ✅ |
| 7. Estados além do feliz | ✅ trata "sem comentário" / "sem avaliação" | ⚠️ não distingue origem | ✅ trata amostra mínima | ❌ ignora amostra mínima |

## Decisão

> **Adotada:** Eixo 1 = **Opção A (assimétrico)**; Eixo 2 = **Opção A (selo "Novo" até 3 avaliações)**.

A privacidade de pessoa física (LGPD) e o incentivo à avaliação honesta do contratante decidem o Eixo 1: nome de **estabelecimento** (PJ pública) é seguro e dá credibilidade; nome de **profissional** não vai a perfil público. A honestidade do número decide o Eixo 2: o público não-técnico confia no score, e amostra mínima precisa ser sinalizada, não maquiada. As demais regras derivam do domínio e do fluxo:

1. **Ordenação:** depoimentos do **mais recente para o mais antigo** (`avaliacoes.created_at` desc) — domínio.
2. **Quantidade no perfil:** até **3 mais recentes** na visão do perfil; quando houver mais, um link **"Ver todas as avaliações (N)"** abre a lista completa como drill-down **dentro do destino Perfil** (mantém o shell — DDR-003).
3. **Avaliação sem comentário NÃO vira depoimento:** entra no score e na **contagem de avaliações**, mas não aparece na lista de depoimentos. Logo, "N avaliações" ≥ "M depoimentos". Quando há score mas nenhum comentário, a seção de depoimentos mostra estado vazio instrutivo (não some).
4. **Data relativa** em pt-BR ("há 3 dias", "há 1 semana", "há 2 meses"); ao passar de ~30 dias, cair para data absoluta `dd/MM/aaaa` (DDR-002, 24h não se aplica a data).
5. **Função do turno** acompanha o autor no depoimento ("· Garçom") — contextualiza sem identificar pessoa.
6. **Limiar do selo "Novo" = 3** é **parâmetro de produto** (vive em `business-rules.md`, ajustável em operação — como os números de XP). O design não fixa o valor, consome-o.

## Consequências

### Positivas

- Régua única de reputação para os dois papéis, com a assimetria de autor explícita e justificada.
- Score honesto desde o dia 1 — não cria nem desfaz reputação com 1 avaliação.
- Perfil legível de relance, dentro do shell, sem virar dashboard.
- Componentes de reputação entram no DS e ficam reutilizáveis (perfil do candidato no painel do contratante, card de vaga com score etc. — usos futuros já cobertos).

### Negativas / trade-offs assumidos

- A regra de autor tem **duas faces** — exige back devolver os campos certos por direção (nome do estabelecimento numa direção; nada de identificável na outra). Risco de vazar nome do profissional se o contrato de leitura for descuidado — **anotado para STORY-088/085**: o endpoint de depoimentos do contratante **não** deve trafegar `autor_id`/nome do profissional para o cliente.
- O selo "Novo" some abruptamente na 3ª avaliação (de "Novo · 2" para "4.x★ · 3"). Aceitável — é o ponto em que a média passa a significar algo.
- Contratante não vê quem o avaliou. Aceitável: ele identifica o turno; moderação de abuso é admin caso-a-caso (fora do MVP).

### Impacto no Design System

Novos itens (registrados em `components.md`/`patterns.md` nesta mesma operação):

- **`input.rating`** (novo componente) — seletor de estrelas 1–5 **obrigatório** da tela de avaliação. 5 estrelas tocáveis (≥48dp cada alvo), estado vazio→selecionado, erro "obrigatório", `Semantics` com valor ("3 de 5 estrelas").
- **`display.rating`** (novo) — estrelas **read-only** + número (1 casa) + contagem; ou o **selo "Novo"** quando < limiar. Variante compacta (linha de score no topo do perfil) e inline (cabeçalho do card de depoimento).
- **`badge.nivel`** (novo) — selo do nível do profissional: Iniciante / Confiável / Destaque / Elite. Texto + ícone; cor **neutra do perfil** (não semântica) — nível não é "status de alerta". Só profissional (contratante não tem nível no MVP).
- **`meter.xp`** (novo) — barra de progresso "XP atual / XP até o próximo nível" + rótulo textual ("Faltam 120 XP para Confiável"). Só profissional. No nível Elite (topo), vira estado "nível máximo" sem barra.
- **`card.depoimento`** (novo) — card de um depoimento: `display.rating` (estrelas) + comentário + linha de autor (variante **estabelecimento-nominal** × **profissional-anônimo**) + data relativa.
- **`badge.novo`** (variante de badge neutro) — selo "Novo na plataforma".
- **`banner.gate`** (novo padrão) — banner **bloqueante proativo** da UX do gate de avaliação (ver `patterns.md` `pattern.gate-avaliacao`): aparece no destino onde vive a ação bloqueada (Vagas, para o profissional; Nova vaga/Minhas vagas, para o contratante), com mensagem pt-BR + CTA "Avaliar agora" que faz deep-link ao turno pendente (`turno_id` da ADR-019). Reativo: se o usuário tentar a ação assim mesmo, o serviço bloqueia (`gate_avaliacao`) e o app reexibe o banner/leva à avaliação.

### Impacto em telas existentes

- **`SCREEN-STORY-084-avaliacao-e-perfil`** (este spec) consome tudo acima.
- **Perfil** (`perfil_screen.dart`, EPIC-012): deixa de ser placeholder — ganha o bloco de reputação (score/nível/XP/depoimentos) acima de Preferências/Sair. STORY-088.
- **Feed do profissional / detalhe de vaga / painel de candidatos** já exibem score/nível do candidato (SCREEN-048/049/051) — quando forem revisitados, devem migrar para `display.rating`/`badge.nivel` do DS (não bloqueante nesta sprint; anotado).

## Implementação sugerida (notas para o Programador)

- Score/nível/XP/contagem vêm prontos do back (ADR-019 — recomputados); o front **só lê e formata**. Não recalcular no cliente.
- Identificadores lógicos sugeridos (viram `Key`/`ValueKey`): `avaliacao-estrelas`, `avaliacao-comentario`, `avaliacao-enviar-btn`, `perfil-score`, `perfil-nivel-badge`, `perfil-xp-meter`, `depoimento-list`, `depoimento-item-<id>`, `gate-banner`, `gate-avaliar-btn`.
- Widget Material base: estrelas = `Row` de `IconButton`/`InkWell` (não há `RatingBar` no Material core — componente custom do DS, como `state_views.dart`); barra de XP = `LinearProgressIndicator` temável; badge de nível = `Container` pílula (mesma família visual de `badge.status`, mas cor de perfil, não semântica).
- **Contrato de leitura (atenção LGPD):** o payload de depoimentos do **contratante** não deve incluir `autor_id` nem nome do profissional — só `papel`, `funcao`, `estrelas`, `comentario`, `data`.

## Critérios para revisitar

- Se o motor de penalidade (PDR-007) entrar e passar a **rebaixar** nível — `badge.nivel`/`meter.xp` precisam comunicar queda.
- Se moderação de avaliação por UI sair do "admin caso-a-caso" — o card de depoimento ganha ação de denúncia.
- Se nível de **contratante** entrar (hoje fora do MVP) — a régua deixa de ser assimétrica em nível.
- Se o limiar "3" do selo "Novo" se mostrar errado na operação — ajustar em `business-rules.md` (não reabre o DDR).
- Depois de ~5 telas usando `display.rating`/`badge.nivel` — reavaliar se a variação cobre os casos reais.

## Aprovação humana

| Campo | Valor |
|---|---|
| Apresentado em | 2026-06-09 |
| Aprovado por | Alexandro |
| Data da aprovação | 2026-06-09 |
| Observações do aprovador | Ratificou em chat as duas escolhas-núcleo: Eixo 1 = assimétrico (estabelecimento nominal / profissional anônimo); Eixo 2 = selo "Novo" até 3 avaliações. Demais regras (ordenação, quantidade, sem-comentário, componentes) derivadas e aceitas. Aprovação do **protótipo navegável** das telas registrada no spec `SCREEN-STORY-084-avaliacao-e-perfil` (CA-5). |

> Decisão-núcleo ratificada pelo dono antes da formalização. Validação visual das telas que a aplicam segue no protótipo do spec.
