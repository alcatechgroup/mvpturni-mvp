---
idr_id: IDR-025
slug: restaura-sessao-no-boot
title: Boot do WebApp restaura a sessão persistida antes do primeiro roteamento
status: accepted
decided_at: 2026-06-02
decided_by: programador
owner_agent: claude-opus-4-8-programador-2026-06-02
related_story: STORY-046
related_adrs: [ADR-007]
related_idrs: [IDR-019]
supersedes: null
superseded_by: null
created_at: 2026-06-02
updated_at: 2026-06-02
---

# IDR-025 — Boot do WebApp restaura a sessão persistida antes do primeiro roteamento

## Contexto

Ao testar a STORY-046 em build servido, abrir `/contratante/vagas/nova` por **URL digitada / reload / bookmark** redirecionava para `/login`, mesmo com o usuário logado e o cookie de sessão Sanctum ainda válido no browser.

No Flutter Web, digitar a URL ou recarregar é um **boot frio**: o estado em memória se perde. O `AuthService` já **gravava** a sessão no `SharedPreferences` no login (`turni_session`) e já tinha o método `loadFromPrefs()` para relê-la — mas **`main()` nunca o chamava**. Resultado: no boot, `AuthService().session` começava `null`, e o funnel guard (STORY-016) mandava **qualquer** rota protegida (inclusive a home `/`) para `/login`. Era um gap app-wide de auth (EPIC-001), latente porque os fluxos anteriores eram alcançados por navegação in-app (sessão em memória) e nenhum teste exercitava deep-link/reload autenticado.

## Decisão

> **Decidi chamar `await AuthService().loadFromPrefs()` no `main()` (após `WidgetsFlutterBinding.ensureInitialized()` e antes do `runApp`), restaurando a sessão persistida antes do go_router avaliar a primeira rota.**

## Por quê

- É a **intenção original** do código (salvar+reler já existiam; só faltava o fio). KISS.
- Restaurar **antes** do `runApp` garante que o funnel guard veja a sessão já no primeiro roteamento — sem flicker de `/login`, sem `refreshListenable` extra, sem estado "carregando" no guard.
- Coerente com ADR-007 (Sanctum SPA por cookie): o cookie httpOnly sobrevive ao reload; o front só precisava reidratar seu `UserSession` para rotear. As chamadas de API seguem usando o cookie; se ele tiver expirado, a API responde 401 normalmente (não revalidamos contra o backend no boot — ver trade-offs).

## Alternativas consideradas

- **`FutureBuilder` no topo do app esperando `loadFromPrefs`**: adiciona uma tela de splash/loading e estado extra no widget tree para o que `await` antes do `runApp` resolve sem custo. Descartada por complexidade desnecessária.
- **`redirect` assíncrono / `refreshListenable` no go_router**: trataria a sessão chegando depois do primeiro frame, mas exige modelar o estado "sessão ainda carregando" no guard (e um redirect temporário). Restaurar antes do `runApp` elimina o problema na raiz.
- **Revalidar a sessão via `GET /api/user` no boot**: mais correto contra cookie expirado, mas adiciona latência de rede no boot e acoplamento. Adiado — o 401 nas chamadas subsequentes já cobre o caso degradado.

## Consequências

### Para outros agentes
- O boot do WebApp agora é **assíncrono** (`Future<void> main()`), e a sessão persistida é a fonte de verdade no primeiro roteamento. Toda rota protegida passa a **sobreviver a reload/deep-link** — considere isso ao escrever cenários (e E2E) que dependem de boot frio.
- Quem precisar de boot frio autenticado em teste: persista a sessão (login real ou `SharedPreferences`) e chame `loadFromPrefs()` para simular o `main()` (o `pumpApp` dos integration_test monta `TurniApp` direto, sem passar pelo `main`).

### Para o projeto
- Corrige um gap app-wide de auth (EPIC-001) exposto pela STORY-046; melhora UX de todas as áreas logadas (reload/bookmark deixam de deslogar visualmente).
- Sem nova dependência; +1 `await` no boot (custo desprezível — leitura local de `SharedPreferences`).

### Trade-offs aceitos
- A sessão restaurada **não é revalidada** contra o backend no boot: se o cookie Sanctum expirou, o usuário vê a UI logada por um instante e recebe 401 na primeira chamada de API. Aceitável no MVP (melhor que deslogar sempre); revalidação via `/api/user` fica como evolução futura se necessário.

## Como verificar

- Unit: `test/auth/session_restore_test.dart` — `loadFromPrefs` restaura sessão válida, mantém nula em storage vazio, descarta corrompida.
- E2E: `integration_test/vagas/publicar_vaga_test.dart` — cenário "deep-link em /contratante/vagas/nova com sessão restaurada mostra o form (não /login)".
- Manual: logar, digitar `/contratante/vagas/nova` na barra de endereço (ou recarregar) → permanece na tela, não vai para `/login`.
