# Princípios de design — detalhado

Os 7 princípios listados em `SKILL.md` em forma resumida. Aqui está o **como aplicar**, **sinais de alerta** e **exemplos** de cada um. Leia esta página inteira antes do primeiro DDR ou primeiro spec de tela.

A ordem importa — em conflito entre princípios, o de cima vence. Quando um spec **viola** um princípio, isso vai explícito em "Exceções ao DS" do spec ou justificado em um DDR.

---

## 1. Simplicidade radical

> A tela mostra o mínimo necessário para a tarefa atual. Complexidade aparece sob demanda (progressive disclosure), nunca de cara.

### Como aplicar

Diante de qualquer tela, faça três perguntas em ordem:

1. **Qual a UMA coisa que o usuário precisa fazer aqui?** Se você não consegue resumir em uma frase, a tela está pedindo simplificação.
2. **O que pode SAIR sem prejudicar a tarefa?** A primeira pergunta diante de excesso é "o que removo?", não "como organizo melhor?".
3. **O que sobrou pode ir para o segundo nível?** Configurações secundárias, filtros avançados, exportações vão para menu/aba/modal — não para a primeira dobra.

### Heurísticas concretas

- **Uma chamada primária de ação por contexto.** Múltiplos CTAs primários competindo → o usuário hesita ou clica errado.
- **Dashboard "cockpit" é red flag.** Tela com 12 widgets equiprioritários geralmente não tem nenhum prioritário de fato. Reduza a 1–3 com hierarquia explícita.
- **Filtros avançados colapsam por padrão.** O usuário básico não vê; o avançado encontra.
- **Configurações vão para "Configurações".** Não tente "facilitar" colocando-as à mão na home.

### Sinais de alerta

- Tela com 2+ CTAs primários (mesma proeminência visual).
- "Vamos colocar tudo na home pra facilitar."
- Usuário precisando de tour guiado para entender uma tela isolada.
- Tela com 5+ blocos de informação sem hierarquia clara.
- Coluna de tabela "que pode ser útil pra alguns clientes" sempre visível.

### Exemplos

**❌ Errado:** Home com 8 cards equiprioritários ("Vagas abertas", "Turnos confirmados", "Match recente", "Avisos", "Atalhos", "Tutoriais", "Notícias", "Promoções").

**✅ Certo:** Home com 1 ação primária ("Aceitar match") + 1 lista contextual ("Em andamento") + acesso secundário no menu.

---

## 2. Mobile-first com paridade desktop

> Toda tela é projetada primeiro para o viewport menor (≥360px). Desktop herda a estrutura e usa o espaço extra com propósito — nunca é "mobile esticado".

### Como aplicar

- Comece o sketch pelo mobile. Se não cabe no mobile, está pedindo simplificação (Princípio #1), não viewport maior.
- No mobile: ação primária acima da dobra, alvos de toque ≥ 44px, navegação por gestos naturais (scroll vertical, swipe entre abas se aplicável), evitar hover-only.
- No desktop: o espaço extra **trabalha** — contexto lateral (navegação persistente, painel de detalhe), múltiplas colunas quando faz sentido (lista + detalhe), atalhos de teclado. Sem espaço vazio à toa.
- Tablet (768px) só ganha layout próprio quando o comportamento muda relevantemente. Caso contrário, escala do mobile ou desktop conforme breakpoint.

Detalhe em `mobile-desktop-parity.md`.

### Sinais de alerta

- Spec só com layout desktop.
- "Mobile a gente adapta depois."
- Hover como única forma de revelar ação importante.
- Tabela larga rolando horizontalmente no mobile sem alternativa.
- Layout desktop com 80% de espaço vazio porque "ficou bom no mobile".

---

## 3. Tom profissional do domínio Turni

> Tipografia, cores, ilustrações, microcopy e densidade visual alinhados a profissional de hospitalidade, gestor de operações, contratante. Sério, mas não árido.

### Como aplicar

- **Tipografia legível, densidade média-alta.** A persona lê muito texto profissional — fonte pequena demais cansa, grande demais infantiliza.
- **Paleta sóbria com 1–2 cores de acento.** Cor primária usada **com parcimônia** (CTA, navegação ativa). Fundo de tela em escala de cinza/branco. Cor saturada em área grande = produto parece de consumo, não profissional.
- **Ilustração comunica ou não existe.** Empty state com instrução visual: ok. Banner decorativo de "pessoas com laptops": não.
- **Microcopy direto e respeitoso.** Sem "Ops!", sem "Uhuu!", sem emoji. Sucesso celebra com discrição: "Match confirmado." não "Yay! 🎉".
- **Sem gamificação sem propósito.** Barras de progresso para passo de wizard: ok. Trilha de níveis do profissional (Iniciante → Confiável → Destaque → Elite) com perks reais: ok — é mecânica de produto. Badges decorativos sem função adicional ("Você concluiu 5 turnos!"): não.

Detalhe em `tone-and-voice.md`.

### Sinais de alerta

- Emojis em microcopy do produto.
- Ilustração genérica de "pessoas com laptops".
- Cor primária saturada cobrindo >20% da tela.
- Copy infantilizado ("Ops, deu ruim!").
- Microinteração com bounce/spring exagerado.
- Mascotes ou personagens.

---

## 4. Padronização > criatividade

> O Design System é o vocabulário. Componente novo só quando o existente realmente não serve — e novo componente entra no DS antes de aparecer numa tela.

### Como aplicar

Antes de desenhar um componente novo, **leia o DS**:

1. **Já tem?** Use. Sem variação por preferência.
2. **Quase serve?** Estenda com variante (e registre no DS).
3. **Não tem mas o padrão é durável?** Cria no DS via DDR antes de usar na tela.
4. **Não tem e é exceção pontual?** Documenta a exceção no spec com justificativa. Se a exceção se repetir 2+ vezes, vira componente do DS.

A consistência vence a criatividade local — o usuário aprende um padrão e o reusa em toda a aplicação.

### Sinais de alerta

- Duas telas com o mesmo conceito (ex.: lista filtrável) usando padrões visualmente diferentes.
- Componente "quase igual" ao do DS criado de novo por preferência.
- Botão primário em 3 cores diferentes em telas diferentes.
- DS desatualizado em relação ao que está em produção.

### Heurística da terceira ocorrência

Mesmo princípio do "DRY com bom senso" do Programador: variação que aparece pela **terceira vez** vira componente no DS. Antes disso, é exceção local.

---

## 5. Acessibilidade como hábito

> Contraste suficiente, navegação por teclado, foco visível, semântica clara, alvos de toque adequados. Não é "modo acessível à parte" — é a única forma de desenhar.

### Como aplicar (piso obrigatório)

- **Contraste WCAG AA:** texto normal ≥ 4.5:1; texto grande (≥18pt) ou ícone significativo ≥ 3:1. Verifique todas as combinações usadas no `ColorScheme`.
- **Foco sempre visível.** Indicador de foco do Material 3 sobrevive em todo elemento interativo (Flutter já entrega isso por padrão em `FilledButton`/`OutlinedButton`/`TextFormField`/`InkWell`). Remover foco sem substituto é bug — vale tanto em Flutter Web (atalho via teclado) quanto em mobile (acessibilidade via switch control).
- **Navegação por teclado completa (Flutter Web).** Tab percorre na ordem visual. Enter/Space ativam. Esc fecha `Dialog`/`BottomSheet`. Setas em lista/menu. Em mobile, equivalente é leitor de tela percorrendo na ordem semântica.
- **Semântica via `Semantics`** (recomendação ao Programador). Botões usam widgets de botão Material/Cupertino (já trazem semântica correta). Quando algo custom for criado, envolve em `Semantics(label: '...', button: true, ...)`. No Flutter Web, isso vira `aria-*` automaticamente.
- **Erro nunca é só cor.** Borda do `TextFormField` em erro + `errorText` + ícone se ajudar. Daltonismo é frequente; daltônico que perde sua mensagem é falha de design.
- **Ícone sozinho como ação** tem label acessível — use `IconButton` com `tooltip:` (Flutter já anuncia via `Semantics`) ou envolva em `Semantics(label: 'Verbo + objeto')`.
- **Alvo de toque ≥ 48×48 dp** em mobile (Material recomenda 48; WCAG aceita 44).
- **Live regions** para mensagens dinâmicas (ex.: `Semantics(liveRegion: true, ...)` envolvendo o conteúdo do `SnackBar`/banner que muda).

Detalhe em `accessibility-basics.md`.

### Sinais de alerta

- Texto cinza claro sobre fundo claro — falha de contraste.
- Foco removido sem substituto (ex.: `FocusableActionDetector` sem indicador custom).
- Erro indicado só por borda vermelha, sem `errorText`.
- `IconButton` sem `tooltip` nem `Semantics(label:)`.
- Alvo de toque <48dp em mobile.
- `Dialog`/`BottomSheet` sem foco-trap (Flutter já trapeia por default — só vira problema se você criar overlay custom).

---

## 6. Performance percebida é parte do design

> Latência é problema de design tanto quanto de back. Skeleton states, otimismo visual, feedback imediato a toque, transições curtas que comunicam progresso. Spinner longo é falha de design.

### Como aplicar

- **Skeleton em vez de spinner.** Tela com carga conhecida (lista, card, tabela) mostra estrutura preenchida com placeholder, não círculo girando em tela branca.
- **Feedback ≤100ms em toda interação.** Botão muda de estado ao mouseDown/touchStart, não só ao mouseUp. Hover→active visível.
- **Otimismo visual** quando seguro. Like contado imediatamente; envio mostra "Enviando…" e confirma; rollback explícito se falhar.
- **Transições curtas (100–300ms) com propósito.** Mudança de tela com fade rápido orienta atenção. Acima de 300ms → cansa.
- **Paginação/virtualização** para listas grandes. 500 itens carregados de uma vez é decisão de design ruim, não só técnica.
- **Lazy load de imagem e bloco fora da dobra.**

### Sinais de alerta

- Spinner centralizado em tela branca por mais de 500ms.
- Botão sem estado pressed.
- Lista de 500+ itens carregada de uma vez.
- Transição de 800ms+ entre telas.
- "Carregando..." como texto único.
- Toda ação síncrona aguardando back antes de qualquer feedback visual.

---

## 7. Estados além do caminho feliz são entregáveis

> Vazio, loading, erro, parcial, sem permissão, offline, dados zerados, primeira-vez vs recorrente: cada um é um estado da tela e precisa ser desenhado e especificado.

### Como aplicar

Toda spec de tela inclui, no mínimo:

- **Vazio** (sem dados ainda — primeira vez ou após filtro sem resultado) — sempre instrui o próximo passo. "Nenhum resultado" sozinho é proibido.
- **Loading** (primeiro fetch e refresh) — skeleton ou parcial preenchido.
- **Erro** com discriminação por tipo (rede, permissão, dado inválido, inesperado) — cada um com microcopy próprio e caminho.
- **Sucesso/preenchido** (caminho feliz) — óbvio, mas explícito.
- **Sem permissão** — quem chega aqui sem permissão vê o quê? Caminho de saída.
- **Parcial/degradado** quando aplicável — parte dos dados falhou, parte carregou.
- **Primeira-vez vs recorrente** quando aplicável — onboarding contextual da primeira vez.

### Sinais de alerta

- Spec só com a tela "preenchida e funcionando".
- "Estado vazio a gente vê na hora."
- Mensagem de erro genérica ("Ocorreu um erro") em vez de erro específico e acionável.
- Loading sem alvo (botão que não muda estado).
- Empty state sem CTA — usuário não sabe o que fazer.

### Heurística do "meio spec"

Se você consegue contar nos dedos da mão quantos estados a tela tem e três deles estão faltando, você entregou meio spec. **Meio spec é zero spec** — Programador vai inventar o que falta, e o que ele inventar provavelmente vai contra os outros princípios.

---

## Hierarquia de conflito

A **Acessibilidade (princípio #5) tem um piso intransponível** — WCAG 2.1 AA. Esse piso vence qualquer outro princípio em conflito. Acessibilidade insuficiente não é trade-off — é bug.

**Acima do piso de acessibilidade**, quando dois princípios brigam, use a ordem abaixo (de cima vence):

1. Simplicidade radical
2. Mobile-first com paridade desktop
3. Tom profissional do domínio Turni
4. Padronização > criatividade
5. Acessibilidade como hábito (acima do piso WCAG AA — refinamentos)
6. Performance percebida
7. Estados além do caminho feliz

Ou seja: o piso de acessibilidade é gate; refinamentos de acessibilidade (que vão além do piso) entram na hierarquia normal.
