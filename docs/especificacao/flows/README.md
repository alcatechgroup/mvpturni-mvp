# Flows — fluxos ponta-a-ponta

Cada arquivo neste diretório descreve um fluxo completo do ponto de vista do usuário, atravessando entidades do domínio. O foco é o **caminho** do usuário; as regras detalhadas vivem em `../domain/`.

## Fluxos previstos

| Fluxo | Quem dispara | Estado |
|---|---|---|
| `cadastro-e-aprovacao.md` | Profissional ou contratante | A escrever |
| `welcome-e-completar-cadastro.md` | Profissional ou contratante (pós-aprovação) | A escrever |
| `publicar-vaga.md` | Contratante | A escrever |
| `feed-e-candidatura.md` | Profissional | A escrever |
| `aceite-da-candidatura.md` | Contratante | A escrever |
| `check-in.md` | Profissional + Contratante | A escrever |
| `execucao-de-turno.md` | Profissional | A escrever |
| `check-out-e-pagamento.md` | Profissional + Contratante | A escrever |
| `avaliacao-reciproca.md` | Profissional + Contratante | A escrever |
| `disputa.md` | Contratante → Admin | A escrever |
| `cancelamento.md` | Profissional ou contratante | A escrever |
| `edicao-de-vaga.md` | Contratante (com candidaturas pendentes) | A escrever |
| `aprovacao-admin.md` | Admin | A escrever |
| `mediacao-de-disputa.md` | Admin | A escrever |

Os fluxos serão escritos **conforme cada épico for definido** — escrever todos antes seria desperdício; o protótipo já é a referência viva enquanto o fluxo específico não estiver detalhado.

## Estrutura sugerida de cada fluxo

```markdown
# Fluxo — <título>

## Quem dispara
<persona>

## Pré-condições
- ...

## Caminho feliz (passo a passo)
1. ...
2. ...

## Variações
### Variação 1 — <nome>
...

## Casos de erro
- ...

## Decisões de produto envolvidas
- PDR-XXX
- PDR-YYY

## Telas envolvidas (referência ao protótipo)
- `docs/prototipo/app.html#/...`
```

## Princípio

Fluxo não detalha UI. Fluxo descreve **comportamento** esperado, decisão por decisão. UI é responsabilidade do Designer; cada estória de UI gera screen spec referenciando o fluxo correspondente.
