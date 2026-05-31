---
id: SCREEN-STORY-023-completar-cadastro-profissional
story: STORY-023-completar-cadastro-profissional-com-aceite
epic: EPIC-001-cadastro-e-aprovacao
status: draft
created_at: 2026-05-30
updated_at: 2026-05-30
owner_designer: claude-opus-programador-designer-2026-05-30
related_ddrs: [DDR-001]
ds_components_used: [brand.logo, stepper, text-field, dropdown, filter-chip, segmented, photo-field, checkbox, button.primary, button.text, banner, contract-preview]
exceptions_to_ds: [contract-preview — superfície de leitura de documento jurídico longo (scroll + tipografia densa); padrão novo proposto para o DS na §10]
viewports: [mobile, desktop]
---

# Spec de tela — SCREEN-STORY-023 — Completar cadastro do Profissional

> Referência: estória `STORY-023`. CAs e contexto vêm de lá — **não duplico**.
> Fundação visual: `DDR-001` + tema profissional (verde). Princípios que guiaram: **#1** simplicidade (um passo por vez), **#2** mobile-first, **#3** tom profissional (é um contrato), **#5** acessibilidade WCAG AA, **#6** performance percebida (preview server-side com skeleton), **#7** todos os estados.
> **Status `draft`:** spec + **protótipo HTML fiel navegável** (`SCREEN-STORY-023-completar-cadastro-profissional/index.html` — 3 passos + preview + conclusão + estados, mobile/desktop, tema dual). Falta só a **validação humana (PO)** da microcopy de consentimento para promover a `ready`.

Esta é a **última tela do funil de identidade** — leva o profissional a `ativo`. O job: coletar dados sensíveis com o mínimo de fricção mental para um público não-técnico, e levar a um **ato de consentimento explícito e informado** (ler o contrato → marcar → aceitar). É a tela mais densa do EPIC-001; a estratégia é **dividir a carga em 3 passos** e só pedir o consentimento depois que o usuário viu o contrato renderizado com os próprios dados.

---

## Decisão de tema e perfil

Usuário **autenticado profissional** → acento **verde** (`accentLight #2D5F3F` / `accentDark #5FA37C`, DDR-001). Marca `TURNI.` (`brandGreen #00A868`) conduz no topo. Tema dual claro/escuro (PDR-013); contrastes na §6.

## Decisão de estrutura (local desta tela)

**Wizard de 3 passos** (`Stepper`), não página única — reduz carga cognitiva do não-técnico (regra de design já praticada no Turni: ≤4 campos por etapa). Mobile: stepper **vertical**; desktop: stepper **horizontal** com barra de progresso. Card no desktop (máx. 640dp), coluna única sem card no mobile. O **preview do contrato** é uma 4ª superfície (tela cheia rolável) alcançada a partir do passo 3.

```
Passo 1 — Identidade      Passo 2 — Atuação          Passo 3 — Financeiro & Documento
 • Documento (CPF/CNPJ)    • Funções secundárias (opc) • Chave Pix
   conforme tipo_pessoa    • Raio máx. (km)            • Documento comprobatório (upload)
                           • Preço/hora (faixa sugerida)
                           • Bio curta (≤500)         → [Revisar e assinar o contrato]
```

Após o passo 3 → botão **"Revisar e assinar o contrato"** abre o **preview** (render server-side, fonte única — CA-7/CA-9). No rodapé do preview: checkbox **"Li, entendi e aceito os termos do contrato"** + CTA **"Aceito e concluir cadastro"** (habilita só com preview rolado/visto **E** checkbox marcado — CA-8).

---

## Fluxo

1. Entrada: profissional `liberado, welcome_visto=true, cadastro_completo=false` cai aqui (funnel guard). Substitui o placeholder de STORY-016.
2. Passo 1 → 2 → 3 (botões "Continuar"/"Voltar"; validação client por passo; rascunho mantido em memória ao navegar entre passos).
3. Passo 3 → "Revisar e assinar" → `POST …/completar-cadastro/preview` → exibe contrato renderizado (Seção 1 + Assinatura) com skeleton enquanto carrega.
4. Usuário rola o preview, marca o checkbox → CTA habilita → "Aceito e concluir cadastro" → `POST …/completar-cadastro` → 201.
5. Sucesso → tela "Cadastro concluído" (placeholder de feed: texto + Sair). Funnel guard não redireciona mais.
6. Saída por erro: banner acionável no passo/preview correspondente; estado preservado.

---

## Layout

### Mobile (≥360dp)
- AppBar com `TURNI.` + indicador "Passo X de 3". Stepper vertical (Material `Stepper(type: vertical)`).
- Campos em coluna, largura total, alvo de toque ≥48dp. Botões "Voltar" (text) + "Continuar" (filled, verde) fixos abaixo do conteúdo do passo.
- Preview: `Scaffold` próprio em tela cheia, `AppBar` "Contrato de adesão" + botão fechar (volta ao passo 3 para editar). Corpo = documento rolável; rodapé fixo (`BottomAppBar`) com checkbox + CTA.

### Desktop (≥840dp)
- Card central (máx. 640dp). Stepper horizontal no topo com os 3 rótulos + barra de progresso.
- Preview: diálogo/overlay full-height (máx. 820dp de largura) com o documento rolável e o rodapé de aceite ancorado.

### Tablet (600–840dp)
- Card central mais estreito; stepper horizontal. Preview como no desktop.

---

## Campos por passo (tipos de widget)

**Passo 1 — Identidade**
- `Documento` — `TextFormField` com máscara dinâmica por `tipo_pessoa` (CPF `000.000.000-00` se PF; CNPJ `00.000.000/0000-00` se MEI/PJ). Rótulo e helper mudam pelo tipo. Validação de dígitos client + server.

**Passo 2 — Atuação**
- `Funções secundárias` — **progressive disclosure** (decisão de design, ver §10): inline aparecem só as funções **selecionadas** como `InputChip` removíveis; a lista completa fica atrás de um botão "Adicionar funções" → **bottom sheet com busca** (`CheckboxListTile`). Evita poluir a tela quando o catálogo de funções é grande. Opcional.
- `Raio máximo de deslocamento` — `TextFormField` numérico, sufixo "km".
- `Preço/hora pretendido` — `TextFormField` numérico, prefixo "R$", helper com **faixa sugerida pela função** ("Garçons costumam cobrar R$ 25–45/h").
- `Bio curta` — `TextFormField` multiline, contador `0/500`.

**Passo 3 — Financeiro & Documento**
- `Chave Pix` — `TextFormField`; helper "CPF, CNPJ, e-mail, telefone (+55…) ou chave aleatória". Validação de formato.
- `Documento comprobatório` — `photo-field` reusado de STORY-017 (estendido p/ PDF): foto do RG/CNH (PF) ou CCMEI/Cartão CNPJ (MEI/PJ). ≤10 MB, JPG/PNG/PDF.

---

## Estados (entregáveis — princípio #7)

- **Padrão (preenchível):** cada passo com seus campos; CTA "Continuar" habilitado quando o passo é válido.
- **Loading do preview:** skeleton de parágrafos (não spinner em tela branca) enquanto `…/preview` responde.
- **Erro de validação (server 422):** mensagem por campo, ancorada ao campo, no passo correspondente; foca o primeiro inválido.
- **Documento duplicado (CA-3):** banner genérico no passo 1 — "Não foi possível concluir o cadastro. Verifique os dados e tente novamente." (sem revelar que o documento existe).
- **Erro de rede/5xx no aceite:** banner no rodapé do preview com "Tentar novamente"; nada foi gravado (transação atômica) — o usuário não perde o que digitou.
- **CTA final desabilitado (CA-8):** enquanto preview não foi visto OU checkbox não marcado — com `Semantics` explicando o porquê.
- **Sucesso:** tela "Cadastro concluído — em breve você terá o feed de vagas" + Sair.
- **Sem permissão / fora do funil:** usuário `ativo` que volta aqui é roteado para o feed (funnel guard); admin não acessa o WebApp.

---

## Microcopy (tabela)

| Elemento | Texto |
|---|---|
| Título | "Complete seu cadastro" |
| Subtítulo | "Faltam alguns dados para você começar a pegar turnos." |
| Passo 1 rótulo | "Identidade" |
| Documento (PF) | label "CPF" · helper "Só você e a equipe Turni veem esse dado." |
| Documento (MEI/PJ) | label "CNPJ" · helper "Só você e a equipe Turni veem esse dado." |
| Passo 2 rótulo | "Atuação" |
| Funções secundárias | "Outras funções que você faz (opcional)" |
| Raio | "Até quantos km você se desloca?" · sufixo "km" |
| Preço/hora | "Seu preço por hora" · prefixo "R$" · helper "Sugestão para {função}: R$ {min}–{max}/h" |
| Bio | "Conte rápido sua experiência (opcional)" · contador "{n}/500" |
| Passo 3 rótulo | "Financeiro e documento" |
| Chave Pix | "Sua chave Pix" · helper "É nela que você recebe em até 15 min após cada turno." |
| Upload | "Foto do seu documento" · helper "RG, CNH ou cartão CNPJ — JPG, PNG ou PDF até 10 MB." |
| CTA passo 3 | "Revisar e assinar o contrato" |
| Preview título | "Contrato de adesão Turni" |
| Checkbox | "Li, entendi e aceito os termos do contrato." |
| CTA final | "Aceito e concluir cadastro" |
| CTA desabilitado (tooltip) | "Role o contrato até o fim e marque o aceite para concluir." |
| Sucesso | "Cadastro concluído. Bem-vindo ao Turni!" / "Em breve você verá o feed de vagas." |
| Erro duplicado | "Não foi possível concluir o cadastro. Verifique os dados e tente novamente." |
| Erro genérico | "Algo deu errado ao concluir. Seus dados estão a salvo — tente novamente." |

> **Revisão PO obrigatória:** a microcopy do contrato/consentimento (checkbox, título do preview) afeta comportamento legal/LGPD — passa por validação do PO antes de produção (fronteira fuzzy do Designer).

---

## Identificadores para teste (Programador aplica como `Key`/`ValueKey`)

`screen-completar-cadastro`, `stepper-completar`, `step-identidade`, `step-atuacao`, `step-financeiro`, `input-documento`, `chips-funcoes-secundarias`, `input-raio`, `input-preco-hora`, `input-bio`, `input-chave-pix`, `field-documento-upload`, `btn-revisar-contrato`, `screen-contract-preview`, `contract-preview-body`, `check-aceite`, `btn-aceito-concluir`, `screen-cadastro-concluido`, `banner-completar-erro`.

---

## Acessibilidade (CA-13)

- Stepper navegável por teclado; foco visível em cada campo; ordem lógica de tab.
- Cada erro associado ao campo via `errorText` (não só cor). Contador de bio anunciado.
- Contraste AA: texto verde-acento sobre off-white e sobre dark conforme tokens DDR-001.
- Preview: documento como região rolável com `Semantics(label: 'Contrato de adesão, role para ler')`; o estado "fim do documento atingido" habilita o checkbox e é anunciado.
- CTA desabilitado expõe `Semantics(hint:)` explicando a condição (não deixa o usuário adivinhar).
- Alvos de toque ≥48dp; upload e chips operáveis por teclado/leitor de tela.

---

## Dependências e contrato de API (alinhado com o Programador)

- `POST /api/usuarios/me/completar-cadastro/preview` → `{ tipo_pessoa, conteudo_renderizado }` (render server-side, sem persistir).
- `POST /api/usuarios/me/completar-cadastro` (multipart) → 201 `{ success, status:'ativo', cadastro_completo:true, aceite_id }`; 422 `{ code }` (`documento_duplicado` | `funil_invalido` | validação por campo).
- Ambas FORA do FunnelGuard (convenção `/api/usuarios/me/*`, IDR-014).
- `GET /api/funcoes` para o multi-select de funções secundárias e a faixa de preço sugerida.

---

## 10. Decisões de design locais (registradas)

- **Seletor de funções com progressive disclosure (PO 2026-05-30):** chips inline só para selecionadas + bottom sheet com busca para a lista completa. Motivo: o catálogo de funções pode ser grande e renderizar tudo em `FilterChip` polui a tela (principalmente mobile). Padrão candidato a DDR se reaproveitado (ex.: função primária no pré-cadastro).
- **Exceção ao DS — `contract-preview`:** superfície de leitura de documento jurídico longo (scroll com detecção de "fim" que habilita o aceite). Sem equivalente no DS. Candidato a DDR se reaproveitado no EPIC-003 (aceite por turno). Por ora, exceção local.

## 11. Sincronismo Designer↔Programador (registrado)

Sessão única (mesmo agente). Decisões alinhadas: render do preview **server-side** (fonte única preview×aceite); reuso de `cadastro/shared/`; 3 passos com Stepper; CTA final gated por preview-visto + checkbox. Detalhe em `STORY-023 §Notas do agente`.

## 12. Pendências para `ready`

- ✅ Protótipo HTML fiel navegável (`SCREEN-STORY-023-completar-cadastro-profissional/index.html`) — 3 passos + preview + conclusão + estados (doc duplicado), mobile/desktop, tema dual.
- ⏳ Validação humana (PO) do protótipo e da microcopy de consentimento.
