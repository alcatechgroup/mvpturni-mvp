---
idr_id: IDR-009
slug: image-picker-para-upload-de-foto
title: image_picker como biblioteca de seleção/upload de foto no WebApp Flutter
status: accepted
decided_at: 2026-05-29
decided_by: programador
owner_agent: claude-opus-programador
related_story: STORY-017
related_adrs: [ADR-001]
related_idrs: []
supersedes: null
superseded_by: null
created_at: 2026-05-29
updated_at: 2026-05-29
---

# IDR-009 — `image_picker` para upload de foto no WebApp

## Contexto

O pré-cadastro de profissional (STORY-017, `SCREEN-STORY-017` componente `input.photo`)
precisa que o usuário selecione uma foto de perfil e a envie via `multipart/form-data`
para `POST /api/cadastro/profissional`. O WebApp é Flutter (ADR-001), alvo MVP = web.
O projeto não tinha biblioteca de seleção de arquivo/imagem. O Designer deixou a escolha
da lib explicitamente para o Programador (spec §13).

## Decisão

> **Decidi usar `image_picker` (pacote oficial do time Flutter) para selecionar a foto,
> lendo os bytes com `XFile.readAsBytes()` e enviando como `http.MultipartFile`.**

## Por quê

- **Oficial e multiplataforma** (Flutter team): em web usa `image_picker_for_web` (um
  `<input type="file">` nativo) sem código específico; o mesmo código serve Android/iOS
  no futuro nativo (princípio: não reinventar, seguir o ecossistema).
- **Bytes diretos** (`readAsBytes`) integram com `http.MultipartFile.fromBytes`, que já é
  a stack HTTP do projeto (`http`, usada em `AuthService`) — sem nova lib de rede.
- **Testável em E2E:** o `<input file>` resultante é dirigível por Playwright via
  `filechooser` — não quebra o gate E2E do WebApp.

## Alternativas consideradas

- **`file_picker`:** mais genérico (qualquer arquivo), porém mais pesado e menos focado;
  `image_picker` já restringe a imagens, alinhado ao requisito.
- **`<input type=file>` via `dart:html` direto:** seria web-only e quebraria a paridade
  multiplataforma; reimplementaria o que o `image_picker` já entrega.

## Consequências

### Para outros agentes
- Reutilizar `image_picker` em STORY-018 (foto do contratante) e STORY-023 (completar
  cadastro). **Não** introduzir `file_picker` ou outro equivalente para a mesma função.
- Padrão de envio: ler bytes do `XFile` e montar `http.MultipartFile.fromBytes` com
  `contentType` derivado da extensão/MIME.

### Para o projeto
- +1 dependência (transitivos: `image_picker_for_web`, `cross_file`, `mime`). Custo baixo;
  pacote estável e mantido pelo time Flutter.

### Trade-offs aceitos
- A validação real de MIME/tamanho continua no servidor (CA-6) — o client valida por UX,
  mas a fonte de verdade de segurança é o `FormRequest`.

## Como verificar

- `pubspec.yaml` declara `image_picker`; nenhuma outra lib de seleção de arquivo coexiste.
- O upload da foto no pré-cadastro funciona no E2E (PF/MEI) em browser real.
