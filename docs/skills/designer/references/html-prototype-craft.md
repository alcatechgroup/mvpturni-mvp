# Ofício do protótipo HTML fiel

Como produzir o **protótipo HTML que acompanha toda spec de tela** do Designer do Turni. Use junto com `templates/screen-spec.md` e `references/screen-spec-craft.md`.

## Por que o protótipo existe

O protótipo HTML serve a **uma única função**: dar ao humano (PO, contratante, profissional entrevistado) **algo que se parece, se sente e flui como a tela vai ficar** — antes de o Programador escrever Flutter.

Spec escrita é abstrata. Sketch ASCII é abstrato. Mockup estático em SVG é abstrato. Nenhum dos três faz o validador descobrir que "ah, esse fluxo não funciona pra mim" — só clicar e percorrer faz.

Decisão errada validada em spec custa baixo. Decisão errada implementada em Flutter custa alto. **O protótipo é o ponto mais barato para errar.**

## Princípios

### 1. Fidelidade visual, não fidelidade técnica

Quem olha o protótipo precisa **reconhecer** a tela final. Cor, tipografia, espaçamento, hierarquia, densidade, tom, motion — tudo extraído dos tokens reais do Design System. Não é wireframe (cinza-block), não é mockup polido demais (que esconde problemas) — é a tela real, sem o back.

### 2. HTML/CSS/JS vanilla, zero build

O Designer não programa Flutter — e também **não programa stack**. O protótipo abre clicando no `index.html` em qualquer máquina, sem `npm install`, sem servidor local, sem dependência externa em runtime. Bibliotecas (ícones, fontes) embarcadas localmente em `assets/`. Frameworks de UI proibidos. Mínima dependência = máxima portabilidade para quem vai validar.

### 3. Mobile-first com paridade navegável

O protótipo carrega exibindo o viewport **mobile** (≥360px). Seletor visível no topo (chips "Mobile / Tablet / Desktop") troca para os outros viewports especificados na seção 3 do spec. Não use detecção automática de viewport — quem valida normalmente está no laptop e precisa ver a versão mobile sem redimensionar janela. Recomendo container fixo com `max-width` por viewport e seletor manual.

### 4. Todos os estados acessíveis a partir do protótipo

Vazio, loading, erro (cada tipo), parcial, sem permissão, sucesso, primeira-vez — todo estado listado na seção 4 do spec precisa estar **alcançável** no protótipo. Use uma das duas estratégias (ou ambas):

- **Seletor de estado visível** (chips ou dropdown no topo): humano clica e vê.
- **Query string** (`?state=empty`, `?state=error-network`): humano com link específico cai direto naquele estado.

Estado que existe no spec mas não no protótipo = estado que ninguém vai validar.

### 5. Microcopy real, vocabulário do domínio

O texto do protótipo é o **mesmo** da tabela de microcopy (seção 5 do spec) — palavra por palavra. "Lorem ipsum" no protótipo invalida o protótipo. Vocabulário segue o glossário do PO ("Vaga", "Turno", "Profissional", "Contratante", "Match", "Estabelecimento").

### 6. Caminho feliz percorrível ponta a ponta

Se a estória cobre múltiplas telas, o protótipo conecta as telas relacionadas com links/`onclick` reais. Clicar no CTA primário leva à próxima tela do fluxo. Se o spec é de uma tela só, indique de onde vem (link "← voltar" para uma stub vazia) e para onde vai (CTA leva a uma página "✓ Próximo passo: ...").

### 7. NÃO é produção

Sem chamada real de API. Sem banco. Sem autenticação real. Sem persistência. Estados de loading usam `setTimeout(..., 800)` ou são selecionáveis manualmente. Dados de exemplo embarcados no próprio HTML/JS.

Topo do `index.html` declara isto explicitamente:

```html
<!--
  Protótipo de validação — Turni
  Tela: STORY-XXX-<slug>
  Atenção: este arquivo é uma maquete navegável para validação humana.
  NÃO é código de produção. Stack final é Flutter (ver docs/skills/programador).
  Última atualização: YYYY-MM-DD
-->
```

### 8. Acessibilidade básica desde já

O protótipo já passa no piso que o spec vai cobrar do Programador:

- HTML semântico (`<button>`, `<label>`, `<nav>`, `<main>`, headings na ordem).
- `alt` em toda `<img>`; ícone-ação tem `aria-label`.
- Contraste WCAG AA em todas as combinações cor/fundo.
- Foco visível por teclado (não remova `:focus-visible`).
- Estrutura tabulável de cima para baixo.

Não é "vou cuidar disso quando virar Flutter". É agora — porque quem valida pode estar usando leitor de tela.

### 9. Atualizado junto com o spec — sempre

Toda mudança no spec (microcopy, estado, fluxo, layout) atualiza o protótipo **na mesma operação**. Protótipo defasado em relação ao spec é pior que ausência de protótipo: engana o validador com algo que não vai ser entregue. Antes de marcar spec como `ready`, refaça o checklist da seção 9 do template.

### 10. Apresentado ativamente ao humano

Você **não** termina dizendo "olha lá na pasta". Você apresenta o `index.html` via `mcp__cowork__present_files` no chat, com uma mensagem curta tipo:

> "Spec da tela X em `STORY-...md` + protótipo HTML em `STORY-.../index.html`. Cobre estados vazio/loading/erro/preenchido em mobile e desktop. Clica no chip de estado no topo. Conta o que ajusto antes de marcar `ready`."

Captura a resposta. Se há ajustes, refaz e re-apresenta. Quando aprovado, registra data em `prototype_last_validated_at` (frontmatter) e em "Histórico de mudanças" (seção 11).

## Estrutura mínima de arquivos

```
docs/project-state/design/screens/STORY-XXX-<slug>/
├── index.html             ← entrada navegável; ponto único de abertura
├── assets/
│   ├── tokens.css         ← cópia local dos tokens do DS aplicáveis
│   ├── components.css     ← estilos dos componentes do DS usados
│   ├── prototype.js       ← seletor de viewport, seletor de estado, mock de loading/transição
│   └── icons/             ← SVGs locais (não CDN)
└── README.md (opcional)   ← notas para quem for validar: "abra index.html, troque estado pelo chip do topo"
```

`tokens.css` e `components.css` são **derivações** do DS oficial, não duplicação eterna. À medida que o DS evolui, sincronize. Se o DS já tem distribuição CSS publicada (futuramente), referencie por caminho relativo em vez de copiar.

## Sequência de produção (encaixa em `screen-spec-craft.md`)

Reaproveite as primeiras etapas (leia estória, identifique estados, rabisco mobile, rabisco desktop, sync com Programador). Depois disso, a sequência fica:

1. **Esqueleto HTML do caminho feliz mobile.** Layout em CSS Grid/Flex, tokens CSS, componentes do DS, microcopy real. Foco em hierarquia e densidade.
2. **Layout desktop no mesmo HTML.** Use `@media (min-width: 1024px)` ou container com classes alternadas pelo seletor de viewport. Mesmo conteúdo, layout adaptado.
3. **Seletor de viewport e seletor de estado.** Chips fixos no topo do protótipo (e/ou query string). Esta é a única "lógica" de produção do protótipo.
4. **Estados restantes** em ordem: vazio → loading → erro → sem permissão → parcial. Cada um implementado como variante de DOM acionada pelo seletor.
5. **Microcopy auditado contra a tabela do spec.** Diferença = bug.
6. **Identificadores estáveis** aplicados como `id` ou `data-testid` no HTML. Mesmo nome lógico que o spec.
7. **Conexões entre telas.** CTAs primários levam à próxima tela (ou stub explícita "✓ próxima tela: ...").
8. **Acessibilidade conferida.** Tabulação, contraste, semântica, `alt`, foco visível.
9. **Apresentar ao humano** via `mcp__cowork__present_files`, capturar feedback, iterar.
10. **Registrar validação** (data + quem) no frontmatter e na seção 11 do spec.

## Sinais de protótipo pronto

- Abre clicando no `index.html` sem nenhum erro de console.
- Mobile e desktop selecionáveis; ambos navegáveis sem layout quebrado.
- Todo estado da seção 4 do spec acessível em ≤2 cliques a partir do topo do protótipo.
- Microcopy = tabela do spec, palavra por palavra.
- Caminho feliz percorrível ponta a ponta (ou stub explícita nas pontas).
- Tokens reais do DS aplicados — quem olha reconhece "isso é Turni".
- Sem CDN, sem `npm`, sem dependência externa em runtime.
- Identificadores estáveis presentes como `id`/`data-testid`.
- Comentário no topo deixa claro que **não** é produção.
- Apresentado via `mcp__cowork__present_files` e sinal humano capturado.

## Sinais de protótipo mal feito

- "Tá quase, faltam só os estados de erro."
- Microcopy diferente do spec (ou pior: `lorem ipsum`).
- Só mobile, ou só desktop.
- CTA não leva a lugar nenhum (`href="#"`).
- Cores e tipografia "aproximadas" — não os tokens reais.
- Estado de loading usando spinner centralizado em tela vazia (viola Princípio #6 do Designer).
- Acessibilidade quebrada (sem `<label>` em campo, sem `alt` em imagem, contraste baixo).
- Dependência de CDN externo que pode quebrar offline.
- Entregue na pasta sem ser apresentado ativamente ao humano para validação.

## Anti-padrões

- **Protótipo bonito demais.** Polimento que esconde dúvida de fluxo é pior que rabisco honesto. Se você está acertando pixel, está usando o tempo errado.
- **Protótipo "vivo" com lógica de back.** Se o protótipo precisa de servidor, login, ou banco, ele deixou de ser protótipo. Mocks inline são a regra.
- **Protótipo gerado e nunca aberto pelo humano.** Sem validação humana, não cumpre função. Não marca `ready`.
- **Protótipo que diverge do spec por "acharia melhor assim".** Decisão de design vai no spec **e** no DDR — depois propaga para o protótipo. Protótipo nunca corre na frente do spec.
- **Protótipo como entrega única.** Continua sendo a spec a fonte canônica. Protótipo é instrumento de validação, não substituto de documento.

## Relação com o protótipo PWA existente (`docs/prototipo/`)

O Turni já tem um **protótipo PWA canônico** em `docs/prototipo/` — referência da fase atual (cobrindo o produto inteiro de forma geral). Os protótipos HTML por estória produzidos pelo Designer são **diferentes**:

| `docs/prototipo/` | `docs/project-state/design/screens/STORY-XXX-<slug>/` |
|---|---|
| Visão geral do produto, várias telas | Uma estória específica, telas dela |
| Referência canônica até a spec consolidar | Validação humana de uma decisão de design |
| Cuidado pelo time mais amplo | Cuidado pelo Designer da estória |
| Atualizado pontualmente | Atualizado junto com o spec |

Não são concorrentes. Quando há sobreposição (uma estória redesenha uma tela do PWA), o protótipo da estória reflete o **novo** desenho proposto; o PWA fica como referência do estado anterior até o épico encerrar e a tela ser portada.
