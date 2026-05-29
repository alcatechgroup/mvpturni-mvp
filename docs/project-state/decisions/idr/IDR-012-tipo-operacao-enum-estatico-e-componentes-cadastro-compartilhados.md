---
id: IDR-012
title: tipo_operacao como enum estático e componentes de cadastro compartilhados (lib/cadastro/shared)
status: accepted
decided_at: 2026-05-29
decided_by: programador
source_story: STORY-018
related: [IDR-008, IDR-009, DDR-001, SCREEN-STORY-018-pre-cadastro-contratante]
---

# IDR-012 — `tipo_operacao` enum estático + componentes de cadastro compartilhados

## Contexto

A STORY-018 (pré-cadastro de contratante) espelha a STORY-017 (profissional): mesmo fluxo
(form único seccionado, foto, aceite de Termos, sem auto-login), tema diferente (mostarda
vs verde — DDR-001) e conjunto de campos parcialmente sobreposto. Duas decisões técnicas
surgiram durante a implementação, ambas previstas como pendência de IDR pela estória
(§"Liberdade técnica do agente") e pela SCREEN-STORY-018 (§A.12).

## Decisão 1 — `tipo_operacao` é um enum estático, não uma tabela auxiliar

Diferente das **funções** do profissional (IDR-008, que viraram tabela com seed porque o
catálogo cresce e é curado pela operação), o **tipo de operação** do estabelecimento é um
conjunto **pequeno, fechado e estável** definido em `domain/usuario.md`:
`restaurante`, `bar`, `hotel`, `evento`, `catering`, `outro`.

- **Back:** validado com `Rule::in(...)` a partir de `StoreContratantePreCadastroRequest::TIPOS_OPERACAO`.
- **Front:** lista estática `TipoOperacao.opcoes` no `contratante_cadastro_service.dart`
  (valor → rótulo exibido). **Não** há `GET /api/tipos-operacao`.

**Forças.** Evitar um endpoint + uma tabela + um seed para 6 valores que não mudam é
simplicidade (menos superfície, menos uma chamada de rede no carregamento da tela). Se um
dia o conjunto precisar ser curado/estendido dinamicamente, migra-se para tabela como as
funções — o custo de reverter é baixo (uma migração + um endpoint).

**Não reabre IDR-008:** funções e tipo de operação têm naturezas diferentes (catálogo
curado e crescente vs enum de domínio fixo). A regra geral continua: enum estático quando
fechado/estável; tabela quando curado/crescente.

## Decisão 2 — Componentes de formulário de cadastro compartilhados em `lib/features/cadastro/shared/`

A 017 §"Liberdade técnica" recomendou **fortemente** extrair componentes compartilhados
para reduzir duplicação entre os dois pré-cadastros. Extraído:

- `shared/cadastro_types.dart` — `FotoUpload`, hierarquia selada `CadastroResult`
  (`CadastroSuccess`/`ValidationError`/`GenericError`/`Throttle`/`ServerError`) e o helper
  `postCadastroMultipart(...)` que concentra **CSRF (Sanctum) + POST multipart + parsing
  da resposta**. Cada serviço (`CadastroService`, `ContratanteCadastroService`) só monta o
  mapa de campos e o path.
- `shared/cadastro_widgets.dart` — widgets de formulário parametrizados pelo `accent` do
  perfil: `CadastroSection`, `CadastroTextField`, `CadastroPasswordField`,
  `CadastroDropdownField<T>`, `CadastroPhotoField`, `CadastroTermsCheckbox`,
  `CadastroErrorText`, `CadastroSuccessView`, `CadastroBanner`/`CadastroBannerWidget`.

A tela do profissional (017) foi **refatorada** para consumir o módulo compartilhado; os
tipos antigos são **re-exportados** por `cadastro_service.dart` para não quebrar imports.
O `segmented` (tipo de pessoa) permanece inline na 017 — é exclusivo do profissional.

**Armadilha resolvida (registrada para o próximo que mexer):** os campos com `Key` precisam
carregar a key **no widget que é filho direto do `Column`** — não só num `Padding` interno.
Quando um erro condicional (ex.: o erro de "tipo de pessoa") é inserido **acima** de um
campo, os irmãos seguintes são reordenados; sem key no filho direto, o Flutter casa os
elementos por **posição** e recria o `FormFieldState`, perdendo o `errorText` recém-validado.
Por isso `CadastroTextField`/`CadastroPasswordField`/`CadastroDropdownField` derivam
`super.key = ValueKey('$fieldKey-field')` automaticamente. (A 017 original já tinha a key no
`Padding` que era filho direto; a regressão só apareceu ao mover a key um nível para dentro
durante a extração — e foi pega pelo widget test "senha fraca" da 017.)

**Forças.** Os dois cadastros divergem só em tema + campos; o fluxo de submit, os estados
(loading/erro/throttle/servidor/sucesso) e a anatomia dos campos são idênticos. Compartilhar
evita que correções (ex.: o fix do 413 de upload) tenham de ser feitas em dois lugares. Os
identificadores lógicos (keys) das specs 017/018 são preservados, então widget tests e E2E
ancoram sem mudança.

## Consequências

- Um terceiro cadastro (ex.: admin, se algum dia for público) reusa `shared/` direto.
- A regra de três do "form único seccionado" (017 + 018) está fechada — o **Designer** deve
  promover esse padrão a **DDR** no próximo ciclo (registrado em SCREEN-STORY-018).
- `tokens.dart` ganhou os tokens de acento **contratante** (`contratanteAccentLight`
  `#9A6E25`, `contratanteAccentInkLight` `#6E4E12`, `contratanteAccentDark` `#D4A95C`),
  valores já sancionados por `tokens.md §6` (DDR-001).
