# Bugs — defeitos encontrados na plataforma

A lista de bugs é um **inventário durável de defeitos observados** ainda não corrigidos. Vive em `docs/project-state/bugs/`. Esta referência diz **como você (PO) opera sobre ela** em qualquer sessão futura.

> Leia também `docs/project-state/bugs/README.md` para a visão geral, esquema dos arquivos, estados e critérios de severidade.

## Quando ativar este fluxo

Detecte intenção do usuário em qualquer destas formas:

| Intenção do usuário | Operação |
|---|---|
| "lista os bugs", "quais bugs temos abertos?", "mostra bugs críticos", "o que falta corrigir?" | **Listar** |
| "adiciona um bug", "encontrei um problema em X", "registra: ao fazer Y aparece Z", "achei isso na validação" | **Adicionar** |
| "promove BUG-XXX para correção", "coloca esse bug no plano", "vamos consertar BUG-XXX" | **Promover para plano** |
| "BUG-XXX é duplicate de BUG-YYY", "fecha BUG-XXX como wont_fix" | **Fechar** (duplicate/wont_fix) |
| "BUG-XXX está confirmado/triado/verificado" | **Atualizar status** |

Quando o pedido for ambíguo ("o que faço com esses bugs?"), pergunte qual operação antes de agir.

## Disciplina de leitura (sempre antes de mexer)

1. `docs/project-state/bugs/bugs.json` — estado atual de todos os bugs.
2. `docs/project-state/bugs/README.md` — convenções, estados, severidade.
3. Bug correlato (mesmo tema/área) para evitar duplicate silencioso.
4. Spec/regra que estabelece o comportamento esperado (`docs/especificacao/`) — sem isso, "bug" pode ser na verdade falta de spec.
5. Validation report do épico relacionado, se aplicável.
6. Sprint atual (`index.json`) — para saber se cabe promover agora.

## Operação 1 — Listar

**Pedido típico:** "lista os bugs"

**Passos:**
1. Leia `bugs.json`.
2. **Default:** agrupe por `status` na ordem: `reported`, `triaged`, `confirmed`, `planned`, `fixed`, `verified`, `wont_fix`, `duplicate`. Dentro de cada grupo, ordene por `severity` (`critical` primeiro) e depois `found_at` mais recente primeiro.
3. **Se o usuário pediu corte por severidade** ("só os críticos", "high e acima"): filtre antes.
4. Formato por linha: `BUG-XXX · [severity] · <título> · status · origin`.
5. Termine com totalizadores por severidade dos status abertos (`reported|triaged|confirmed`) e link `computer://` para o JSON e diretório `items/`.
6. Se houver `critical` em `reported`/`triaged` há mais de 1 dia, **destaque no topo** — é alerta de processo.

**Não:** não abra cada `.md` para detalhe a menos que o usuário peça um bug específico.

## Operação 2 — Adicionar

**Pedido típico:** "adiciona um bug", "encontrei um problema: <descrição>"

**Passos:**
1. Identifique o que já veio na mensagem.
2. **Use `AskUserQuestion` apenas para o que falta.** Máximo 4 perguntas curtas. Campos mínimos para criar o item:
   - **Título canônico** (1–2 sugestões se o usuário não deu).
   - **Reprodução curta** (3–5 passos + frequência se souber).
   - **Esperado × observado** (uma frase cada).
   - **Severidade** (ofereça as 4 opções com critério do README) — se o usuário não souber, sugira com base no impacto que ele descreveu e confirme.
3. Pergunte `origin` apenas se não estiver óbvio do contexto da sessão (em sessão de validação, `origin: validation` é default).
4. Calcule próximo `id` = `BUG-{bugs.json.next_id}` formatado em 3 dígitos.
5. Defina `slug` em kebab-case ASCII derivado do título.
6. Crie `items/BUG-XXX-<slug>.md` a partir de `docs/skills/po/templates/bug.md`. Preencha tudo que conseguir; seções sem dado ficam com `<a confirmar na triagem>` — **não invente reprodução**.
7. Atualize `bugs.json`:
   - Adicione entry em `items[]` com `status: "reported"`.
   - Incremente `next_id`.
   - Atualize `generated_at`.
8. Atualize o `summary` no `index.json` principal (chave `bugs.summary` — `total`, `by_status`, `by_severity_open`).
9. Confirme no chat com `id` criado, severidade, e link `computer://` para o `.md`. **Se severidade for `critical`**, sugira ao usuário promover agora.

**Não:** não crie estória de correção na operação de adicionar — isso é só captura. Promoção é Operação 3.

## Operação 3 — Promover para o plano

**Pedido típico:** "promove BUG-XXX para correção"

### Passo 1: leia o bug inteiro

Abra `items/BUG-XXX-<slug>.md`. Confirme que tem reprodução, esperado × observado, severidade.

### Passo 2: confirme reprodução (se ainda não)

Se status for `reported` ou `triaged`, peça ao usuário confirmação ou reproduza você mesmo se o canal permite. Mude para `confirmed` antes de promover. Bug `wont_fix`/`duplicate` **não** se promove.

### Passo 3: decida o destino

Quase sempre vira **estória de correção** em épico existente ou novo:

| Cenário | Destino |
|---|---|
| Bug em épico ativo, fix cabe no sprint atual | Estória no épico ativo, dentro do sprint corrente (cuidado com soft-cap). |
| Bug em épico ativo, fix não cabe no sprint atual | Estória no épico ativo, **fora** do sprint corrente (sem `sprint_id` ou no próximo sprint). |
| Bug em épico já `done` (regressão ou caudal de validação) | Estória nova no épico mais aderente da onda atual, ou em épico de "estabilização" se a onda tiver um. |
| Bug em área sem épico vigente | Aceitar `triaged` e deixar para próxima onda — não force estória órfã. Sinalize no próximo status report. |
| Bug que revela falta de regra de negócio (não é bug, é spec faltando) | Não é bug. Reclassifique: feche como `wont_fix` com motivo "reclassificado como falta de spec" e crie WISH-XXX (wishlist) ou PDR conforme o caso. |

Para bug `critical`, o destino padrão é estória no sprint corrente — converse antes de empurrar para depois.

### Passo 4: crie a estória (Fluxo C)

Use `templates/story.md`. Convenções específicas para correção:

- **Tipo:** `type: bug_fix` no frontmatter.
- **Título:** comece com "Corrigir: " + título do bug.
- **Contexto:** referencie o `items/BUG-XXX-<slug>.md` no topo da seção "Contexto e referências".
- **CAs:** o primeiro CA é sempre "reprodução do BUG-XXX não acontece mais, validada nos mesmos passos descritos no item". Os demais cobrem regressão (não introduzir novos bugs em áreas vizinhas) e padrões de qualidade (cobertura, E2E).
- **DoD:** inclui "BUG-XXX marcado como `fixed` no `bugs.json`; quando verificado em homolog/prod, marcado como `verified`".

### Passo 5: feche o ciclo no item de bug

1. No arquivo `items/BUG-XXX-<slug>.md`:
   - Mude `status` para `planned`.
   - Preencha `fix_link` com path da estória (relativo à raiz do projeto).
   - Atualize `updated_at`.
   - Adicione linha em "Notas / histórico" registrando a promoção.
2. No `bugs.json`:
   - Atualize a entry: `status`, `fix_link`, `updated_at`.
   - Atualize `generated_at`.
3. No `index.json` principal: atualize `bugs.summary` e `stories[]` (entry da estória nova).

### Passo 6: confirme no chat

Resumo: bug promovido, estória criada (id + path), em qual sprint/épico. Link `computer://` para a estória e para o bug atualizado.

## Operações auxiliares

### Fechar como `wont_fix`

1. Confirme motivo com o usuário (custo > benefício, fora de escopo, comportamento aceitável).
2. No `.md`: `status: wont_fix`, preencha `wont_fix_reason`, atualize `updated_at`, registre em "Notas / histórico".
3. No `bugs.json`: mesma atualização.
4. Se for `critical` ou `high`, **considere registrar um PDR** justificando a decisão — é decisão de produto com peso.

### Fechar como `duplicate`

1. Confirme o "pai" (BUG-YYY ou STORY-YYY).
2. No `.md`: `status: duplicate`, preencha `duplicate_of`, atualize `updated_at`, registre.
3. No `bugs.json`: mesma atualização.
4. No `.md` do pai: adicione linha em "Notas / histórico" referenciando o duplicate.

### Marcar `confirmed` / `triaged` / `verified` sem promover

Permitido para movimentos:

- `reported → triaged` (PO leu, classificou).
- `triaged → confirmed` (reprodução comprovada).
- `fixed → verified` (verificação após o fix entregue).
- `confirmed → reported` ou `triaged → reported` (reverter se foi engano).

Atualize frontmatter do `.md`, entry em `bugs.json`, e `last_seen_at` se voltou a ocorrer.

**Não:** `reported → planned` direto não é permitido — passe por `triaged → confirmed` antes (mesmo que rápido), porque promover sem confirmar reprodução gera estória sem CA testável.

## Invariantes

1. `bugs.json` reflete o estado real dos `.md`. Divergência é bug — corrija na hora.
2. ID é imutável. `wont_fix`/`duplicate` **não** liberam número.
3. Status `planned` exige `fix_link` preenchido.
4. Status `wont_fix` exige `wont_fix_reason`.
5. Status `duplicate` exige `duplicate_of`.
6. Status `verified` exige `fix_link.status == done` (a estória de correção foi entregue).
7. `next_id` em `bugs.json` é sempre `max(id existente) + 1`.
8. Bug com severidade `critical` aberto (`reported`/`triaged`/`confirmed`) por mais de 24h aparece como alerta em status report.
9. Arquivos `.md` da lista de bugs **nunca** são apagados.

## Quando NÃO usar a lista de bugs

- **Incidente operacional ao vivo** (produção fora do ar agora) — siga runbook; só registre bug depois se houver defeito de código a corrigir.
- **Falta de spec** — não é bug. Reclassifique como wishlist ou PDR.
- **Sugestão de melhoria** — não é bug. Vai para wishlist.
- **Pergunta de "isso deveria funcionar assim?"** — não é bug ainda. Confirme expectativa antes (spec, protótipo, PDR). Se confirmar que diverge, então abre.

## Relação com a wishlist

| Característica | Wishlist (WISH-) | Bugs (BUG-) |
|---|---|---|
| Natureza | "seria bom ter" | "está errado, conserta" |
| Tem expectativa estabelecida? | Não — é desejo novo | Sim — diverge de spec/protótipo/PDR |
| Severidade | Não tem | Sempre (`critical`/`high`/`medium`/`low`) |
| Reprodução | Não exige | Exige (sem ela, fica `reported` esperando triagem) |
| Promoção típica | Estória, PDR ou spec funcional | Estória de correção (`type: bug_fix`) |
| Origem comum | Alexandro/PO em conversa | Validação, usuário, monitoring |

Em dúvida sobre qual lista usar, pergunte ao usuário ou cheque: **existe spec/protótipo/PDR que diz que isso deveria funcionar de outro jeito?** Sim → bug. Não → wishlist.

## Pegadinhas comuns

- **Promover sem confirmar reprodução.** Estória de correção sem CA testável é estória ruim. Sempre passe por `confirmed`.
- **Severidade inflada.** "Critical" virar default mata a priorização. Use o critério estrito do README.md.
- **Bug que é falta de spec.** Reclassifique — não force fix de algo cujo "esperado" ninguém escreveu.
- **Esquecer de atualizar `bugs.json` e o `summary` no `index.json`.** Toda alteração em `.md` exige sincronização nos dois lugares.
- **Não vincular ao `validation/report.md` quando aplicável.** Perde a rastreabilidade do épico → bug → fix.
