# Wishlist — pre-backlog do PO

A wishlist é um **estoque durável de desejos** que ainda não foram priorizados, especificados ou rejeitados. Vive em `docs/project-state/wishlist/`. Esta referência diz **como você (PO) opera sobre ela** em qualquer sessão futura.

> Leia também `docs/project-state/wishlist/README.md` para a visão geral e o esquema dos arquivos.

## Quando ativar este fluxo

Detecte intenção do usuário em qualquer destas formas (português ou inglês, formal ou informal):

| Intenção do usuário | Operação |
|---|---|
| "lista a wishlist", "quais desejos temos?", "mostra o que tem na lista", "o que está pendente?" | **Listar** |
| "adiciona um desejo: X", "inclui um item", "anota aí: X", "quero pedir uma feature" | **Adicionar** |
| "transforma WISH-XXX em spec", "promove esse desejo", "vamos especificar o WISH-001", "vira estória" | **Transformar em spec** |
| "rejeita o WISH-XXX", "esse não vamos fazer" | **Rejeitar** (variante de promover, sem criar artefato) |
| "marca o WISH-XXX como triado/aceito" | **Atualizar status** (sem promover ainda) |

Quando o pedido for ambíguo ("o que faço com essa wishlist?"), pergunte qual operação antes de agir.

## Disciplina de leitura (sempre antes de mexer)

1. `docs/project-state/wishlist/wishlist.json` — estado atual de todos os itens.
2. `docs/project-state/wishlist/README.md` — convenções e estados.
3. PDRs vigentes relacionados ao tema do item (em `decisions/pdr/`).
4. Especificação relevante (`docs/especificacao/`) — para saber se já existe contrato durável que o desejo afeta.
5. Sprint/épico atual (`index.json`) — para decidir se promoção encaixa agora ou só na próxima onda.

## Operação 1 — Listar

**Pedido típico:** "lista a wishlist", "quais desejos temos?"

**Passos:**
1. Leia `wishlist.json`.
2. Agrupe itens por `status` na ordem: `new`, `triaged`, `accepted`, `specced`, `done`, `rejected`.
3. Apresente em prosa curta. Formato sugerido por linha: `WISH-XXX · <título> · <one-liner em meia linha>`.
4. Se o usuário pediu filtro (status, tag), aplique antes de exibir.
5. Termine com totalizador (`X new · Y triaged · …`) e link `computer://` para o JSON e para o diretório `items/`.

**Não:** não abra cada `.md` para ler conteúdo descritivo a menos que o usuário peça detalhe de um item específico. O JSON basta para a listagem.

## Operação 2 — Adicionar

**Pedido típico:** "adiciona um desejo: <coisa>", "inclui na wishlist: <coisa>"

**Passos:**
1. Identifique o que já veio na mensagem. Se o usuário deu título + uma frase de contexto, isso é suficiente para começar.
2. **Use `AskUserQuestion` apenas para o que falta** — no máximo 2–3 perguntas curtas. Campos essenciais para criar o item:
   - **Título canônico** (se o usuário não deu, sugira 1–2 opções derivadas da descrição).
   - **One-liner** (problema + comportamento esperado, observável pelo usuário).
   - **Valor esperado** (a quem serve, por que importa) — só pergunte se não estiver óbvio.
3. Calcule o próximo `id` = `WISH-{wishlist.json.next_id}` formatado em 3 dígitos.
4. Defina `slug` em kebab-case ASCII derivado do título.
5. Crie o arquivo `items/WISH-XXX-<slug>.md` a partir de `docs/skills/po/templates/wish.md`. Preencha tudo que conseguir; deixe seções não respondidas com placeholder (`<a definir na triagem>`) — não invente.
6. Atualize `wishlist.json`:
   - Adicione entry em `items[]` com `status: "new"`.
   - Incremente `next_id`.
   - Atualize `generated_at`.
7. Confirme no chat com o `id` criado e link `computer://` para o `.md` novo.

**Não:** não crie PDR, estória ou spec na operação de adicionar. Isso é só captura.

## Operação 3 — Transformar em spec

**Pedido típico:** "transforma WISH-XXX em spec", "promove o WISH-XXX"

Esta é a operação mais cuidadosa — promoção move o item de "intenção" para "compromisso". Faça uma decisão de **destino** antes de qualquer coisa.

### Passo 1: leia o item completo

Leia `items/WISH-XXX-<slug>.md` inteiro + PDRs e specs citados nas Referências. Confirme contexto.

### Passo 2: decida o destino (1 dos 4)

| Tipo de desejo | Destino | Exemplo |
|---|---|---|
| Adicionar/mudar regra de negócio, vocabulário, domínio ou fluxo durável | Atualizar arquivo em `docs/especificacao/` | "permitir cancelamento até 1h antes" |
| Trabalho implementável que encaixa em épico existente | Criar estória via Fluxo C (`templates/story.md`) no épico apropriado | "campo de telefone com máscara" |
| Trabalho implementável que justifica épico novo (ou onda nova) | Criar épico via Fluxo A/B; encostar no `current-wave.md` ou `next-wave.md` conforme priorização | "área de mensagens entre profissional e contratante" |
| Decisão de produto sem trabalho imediato (escolha de escopo, política, persona) | Criar PDR em `decisions/pdr/` | "MEI vira tipo de pessoa padrão para profissionais" |

Em dúvida entre os quatro, **converse com o usuário antes** — promoção errada vira retrabalho.

### Passo 3: execute o fluxo PO correspondente

- **Spec funcional:** edite o(s) arquivo(s) em `docs/especificacao/` seguindo convenção do diretório. Cite o `WISH-XXX` na seção "histórico" do arquivo de spec quando aplicável.
- **Estória:** siga o Fluxo C da `SKILL.md`. Use `templates/story.md`. Adicione no épico apropriado. Atualize `index.json` (entry em `stories[]`, entry em `epic.story_ids`, etc — invariantes de `references/indexing.md`).
- **Épico novo:** siga Fluxo A/B. Atualize `index.json`. Considere se a onda atual aguenta ou se vai para a próxima.
- **PDR:** use `templates/pdr.md`. Adicione em `decisions/pdr/`. Atualize `index.json` (`decisions.pdr[]`).

### Passo 4: feche o ciclo no item da wishlist

1. No arquivo `items/WISH-XXX-<slug>.md`:
   - Mude `status` no frontmatter para `specced`.
   - Atualize `updated_at`.
   - Preencha `spec_link` com o caminho do artefato resultante (relativo à raiz do projeto). Se forem vários, liste todos.
   - Adicione linha em "Notas / histórico" descrevendo a promoção.
2. No `wishlist.json`:
   - Atualize a entry do item: `status`, `spec_link`, `updated_at`.
   - Atualize `generated_at`.

### Passo 5: confirme no chat

Resumo curto: o que foi promovido, para onde, o que ainda precisa decidir (se algo). Links `computer://` para os artefatos criados/editados.

## Operação 4 — Rejeitar

**Pedido típico:** "rejeita o WISH-XXX porque <motivo>"

1. Confirme o motivo com o usuário se ainda não foi dado.
2. No `.md` do item: `status: rejected`, preencha `rejected_reason`, atualize `updated_at`, registre em "Notas / histórico".
3. No `wishlist.json`: mesma atualização.
4. **Não** apague o arquivo. Rejeitado fica como memória — número não é reciclado.

## Operação 5 — Atualizar status sem promover

**Pedido típico:** "marca o WISH-XXX como triado/aceito"

Permitido para movimentos:

- `new → triaged` (você leu, entendeu, vinculou contexto, mas ainda não decidiu).
- `triaged → accepted` (decisão informal de "isso vai entrar em algum momento", sem promover ainda).
- `accepted → triaged` (reverter, se mudou de ideia).

Atualize frontmatter do `.md` e entry em `wishlist.json`. Registre em "Notas / histórico" o motivo da mudança.

`new → specced`, `triaged → specced`, `accepted → specced` só via Operação 3 (não trate como simples mudança de status).

## Invariantes

1. `wishlist.json` reflete o estado real dos `.md`. Se divergir, é bug — corrija na hora.
2. ID é imutável. Rejeitado **não** libera número.
3. Toda promoção a `specced` preenche `spec_link`. Status `specced` sem link é estado inválido.
4. `next_id` em `wishlist.json` é sempre `max(id existente) + 1`.
5. Item `done` só existe se o `spec_link` aponta para artefato concluído (épico/estória `done`). Trate como sincronização opcional — não é obrigatório atualizar wishlist quando estória conclui, mas se o usuário pedir, faça.
6. Arquivos `.md` da wishlist **nunca** são apagados.

## Quando não usar a wishlist

- Para registrar **decisão tomada** — use PDR.
- Para itens já priorizados na onda/sprint — use épico/estória.
- Para nota efêmera ("lembrar de tal coisa amanhã") — use o canal apropriado fora do project-state.

## Pegadinhas comuns

- **Confundir wishlist com backlog.** Backlog = compromisso de entrega ordenado. Wishlist = inventário sem compromisso. Não use wishlist para ordenar trabalho do sprint.
- **Adicionar com 7 perguntas.** No máximo 3. Falta de detalhe vira `<a definir na triagem>` no `.md` — não bloqueie a captura.
- **Promover sem ler PDRs vigentes.** WISH-002 (CNPJ) é o exemplo canônico: PDR-001 restringe o uso. Não promova item sem confirmar que decisões anteriores não foram violadas.
- **Esquecer de atualizar `wishlist.json`.** Toda alteração em `.md` exige atualização no JSON na mesma operação.
