# Runbook de execução — STORY-071 (refactor Flutter `apps/webapp`, IDs como `String`)

> Produzido pela STORY-069 (spike). Interface mecânica entre o spike e a execução do
> frontend. Decisão 7 da ADR-018 é vinculante: **IDs viram `String`/`String?` em DTOs,
> services e widgets**. O domínio Flutter trata o id como string opaca — **não** valida
> formato UUID (quem valida é o backend). Inventário de `int`/`int?` abaixo levantado por
> grep em 2026-06-03; reconferir os números de linha antes de editar (podem ter andado).

## Princípio de conversão

- `int id` → `String id`; `int? *_id` / `int? *Id` → `String? *Id`.
- Parsing JSON: `(json['x'] as num).toInt()` → `json['x'] as String`;
  `(json['x'] as num?)?.toInt()` → `json['x'] as String?`. Remover `?? 0` (o fallback
  numérico não faz sentido para string; usar `''` só se a UI realmente precisar de
  não-nulo, senão manter `String?`).
- Sem aritmética sobre id em lugar nenhum (confirmado) — a troca é puramente de tipo.

---

## 1. DTOs / models — campos a retipar

| Arquivo | Linha (aprox.) | Hoje | Vira |
|---|---|---|---|
| `lib/features/feed/feed_service.dart` | 46 | `final int id;` | `final String id;` |
| `lib/features/feed/feed_service.dart` | 74 | `id: (json['id'] as num).toInt()` | `id: json['id'] as String` |
| `lib/features/notificacoes/notificacao.dart` | 32 | `final int id;` | `final String id;` |
| `lib/features/notificacoes/notificacao.dart` | 34 | `final int? vagaId;` | `final String? vagaId;` |
| `lib/features/notificacoes/notificacao.dart` | 35 | `final int? candidaturaId;` | `final String? candidaturaId;` |
| `lib/features/notificacoes/notificacao.dart` | 53–56 | `(json['…'] as num?)?.toInt()` | `json['…'] as String?` (e `id` como `String`) |
| `lib/features/vagas/vaga_service.dart` | 63, 155 | `final int id;` | `final String id;` |
| `lib/features/vagas/vaga_service.dart` | 86, 178 | `id: (json['id'] as num).toInt()` | `id: json['id'] as String` |
| `lib/features/vagas/vaga_service.dart` | 180 | `funcaoId: (json['funcao_id'] as num?)?.toInt() ?? 0` | `funcaoId: json['funcao_id'] as String?` (retipar campo p/ `String?`) |
| `lib/features/vagas/vaga_service.dart` | 316 | `(data['id'] as num?)?.toInt() ?? 0` | `data['id'] as String` |
| `lib/features/vagas/vaga_detalhe_service.dart` | 97 | `final int? id;` | `final String? id;` |
| `lib/features/vagas/vaga_detalhe_service.dart` | 140 | `final int id;` | `final String id;` |
| `lib/features/vagas/vaga_detalhe_service.dart` | 111, 176 | parse `as num` | `as String?` / `as String` |
| `lib/features/vagas/candidatos_service.dart` | 11, 53 | `final int id;` | `final String id;` |
| `lib/features/vagas/candidatos_service.dart` | 39, 73 | `(json['id'] as num?)?.toInt() ?? 0` | `json['id'] as String` |
| `lib/features/vagas/candidatura_service.dart` | 49 | `final int id;` | `final String id;` |
| `lib/features/vagas/candidatura_service.dart` | 28, 137 | parse `vaga_id`/`id` `as num` | `as String?` / `as String` |
| `lib/features/cadastro/cadastro_service.dart` | 13 | `final int id;` (model `Funcao`) | `final String id;` |
| `lib/features/cadastro/cadastro_service.dart` | 19 | `id: json['id'] as int` | `id: json['id'] as String` |
| `lib/features/cadastro/cadastro_service.dart` | 50 | `required int funcaoId` | `required String funcaoId` |
| `lib/features/cadastro/cadastro_service.dart` | 67 | `'funcao_id': funcaoId.toString()` | `'funcao_id': funcaoId` (já é string; remover `.toString()`) |
| `lib/features/cadastro/completar_cadastro_service.dart` | 34, 40, 48 | `int? funcaoId` / `json['funcao_id'] as int?` | `String? funcaoId` / `as String?` |
| `lib/features/cadastro/completar_cadastro_service.dart` | 126 | `required List<int> funcoesSecundarias` | `required List<String> funcoesSecundarias` |
| `lib/features/cadastro/completar_cadastro_service.dart` | 145–146 | `funcoesSecundarias[i]…toString()` | enviar `funcoesSecundarias[i]` (já string; remover `.toString()`) |

---

## 2. Service methods que recebem `int id`

| Arquivo | Linha | Hoje | Vira |
|---|---|---|---|
| `lib/features/notificacoes/notificacoes_service.dart` | 43 | `Future<bool> marcarLida(int id)` | `marcarLida(String id)` |
| `lib/features/vagas/vaga_detalhe_service.dart` | 229 | `Future<DetalheResult> fetch(int id)` | `fetch(String id)` |

---

## 3. Widgets / dropdowns tipados `<int>`

| Arquivo | Linha | Hoje | Vira |
|---|---|---|---|
| `lib/features/cadastro/pre_cadastro_profissional_screen.dart` | 492 | `CadastroDropdownField<int>` (função) | `CadastroDropdownField<String>` |
| `lib/features/vagas/publicar_vaga_screen.dart` | 295, 309, 522 | `DropdownMenu<int>` / `DropdownMenuEntry<int>` / `ValueChanged<int>` | `<String>` |
| `lib/features/vagas/editar_vaga_screen.dart` | 430, 444, 885 | `DropdownMenu<int>` / entry / `ValueChanged<int>` | `<String>` |
| `lib/features/vagas/editar_vaga_screen.dart` | 137 | `_funcaoNome(int? id)` | `_funcaoNome(String? id)` |
| `lib/features/cadastro/completar_cadastro_screen.dart` | 65 | `Set<int> _funcoesSecundarias` | `Set<String>` |
| `lib/features/cadastro/completar_cadastro_screen.dart` | 769 | `Set<int> selecionadas` | `Set<String>` |
| `lib/features/cadastro/completar_cadastro_screen.dart` | 770 | `void Function(int id, bool) onToggle` | `Function(String id, bool)` |

> `CadastroDropdownField<T>` (em `lib/features/cadastro/shared/cadastro_widgets.dart`) já é
> genérico — só os call sites mudam `<int>`→`<String>`. O comentário "Profissional usa
> `<int>` (função)" deve virar "`<String>`".

---

## 4. Router — parâmetros de rota

`lib/router.dart` (linhas ~160, 191, 207) faz
`final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;` para as rotas
`/contratante/vagas/:id/editar`, `/contratante/vagas/:id/candidatos` e a rota de detalhe da
vaga. Trocar por:

```dart
final id = state.pathParameters['id'] ?? '';
```

e retipar os parâmetros das telas: `VagaDetalheScreen(vagaId: String)`,
`EditarVagaScreen(vagaId: String)`, `PainelCandidatosScreen(vagaId: String)`. As
`ValueKey('vaga-$id')` / `ValueKey('editar-vaga-$id')` continuam válidas (interpolação de
string). Onde a tela usa `vagaId` para montar a URL da chamada de API, passa a string direto.

---

## 5. `score_breakdown` (JSON) — sem impacto

CA-7 do spike: o `score_breakdown` (lido pelo painel de candidatos e detalhe de vaga) **não
contém IDs** — só `total`, `componentes` (inteiros) e `breakdown` (pontos/estado/descrição).
O parsing do breakdown no Flutter **não muda**. Não há campo de id para retipar dentro do JSON.

---

## 6. Testes a auditar e re-rodar

### 6.1 Unit/widget (`apps/webapp/test/`)
Helpers de fixture com `int id = 1` — trocar default para `String id = '...uuid...'` (ou um
literal estável tipo `'00000000-0000-7000-8000-000000000001'` se a asserção depender do valor):

- `test/feed/feed_screen_test.dart:33` (`int id = 1`)
- `test/feed/feed_service_test.dart:12` (`int id = 1`)
- `test/features/notificacoes/notificacoes_test.dart:14` (`int id = 1`)
- `test/vagas/painel_candidatos_screen_test.dart:65` (`int id = 1`)
- `test/vagas/minhas_vagas_screen_test.dart:36` (`int id = 1`)
- `test/vagas/revisao_apos_edicao_test.dart:18,28,34` (`fetch(int id)` / `manterAposEdicao(int id)` / `retirarAposEdicao(int id)` — alinhar com as assinaturas `String` dos services)

> `integration_test/feed/feed_test.dart:20` `int _contaCards(...)` é **contagem de widgets**,
> não id — **não mexer**.

### 6.2 E2E Playwright (`apps/webapp/tests/e2e/`)
- `pre-cadastro.spec.ts`, `pre-cadastro-contratante.spec.ts`: interagem com a UI (selecionam
  função pelo **label** do dropdown, não pelo id) — provavelmente não asseram id numérico.
  **Varrer** por id numérico hardcoded em `tests/e2e/fixtures/` e por asserções de URL com id
  numérico (`/vagas/1`). Onde houver, trocar por matcher de uuid ou por captura dinâmica.
- Rodar smoke same-origin conforme harness do IDR-021 (memória
  `e2e-same-origin-harness`) — lembrando que E2E logado é **local**, não homolog
  (memória `e2e-local-gate-nao-homolog`).

### 6.3 Lint/format obrigatórios antes do push (memória `lint-local-antes-de-push`)
```bash
cd apps/webapp && flutter analyze && dart format --set-exit-if-changed .
```
(O CI cobre mais que o hook; rodar local antes de empurrar.)

---

## 7. Checklist de saída (para STORY-072)

- [ ] `grep -rn 'as num).toInt()\|as int\|<int>\|int? .*[iI]d\|int id' apps/webapp/lib` não
  retorna nenhum caso ligado a **id** (contadores e outros inteiros legítimos podem ficar).
- [ ] `flutter analyze` limpo; `dart format` sem diffs.
- [ ] Suíte `flutter test` verde; `integration_test` (área logada, local) verde.
- [ ] App abre no browser e os fluxos de função (pré-cadastro, completar cadastro, publicar/
  editar vaga, candidatura, painel) funcionam com id string (verificar de verdade no browser —
  memória `verificar-ui-no-browser`).
</content>
