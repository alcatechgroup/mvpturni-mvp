# Craft de escrita de estória

O template de estória (`templates/story.md`) dá o formato. **Esta reference dá o ofício** — como escrever uma estória que um agente de programação consegue executar em uma sessão sem voltar com perguntas, e que o validador consegue verificar sem ambiguidade.

Estória boa não é estória "completa" — é estória **suficientemente clara**. A diferença está nos detalhes.

---

## A mentalidade

- **Estória é contrato com o agente programador.** Se ela está ambígua, ele inventa. Se ela está prolixa, ele se perde. Você está sendo claro o suficiente?
- **Cada estória atravessa o stack ou entrega algo observável.** Não é unidade técnica — é unidade de valor.
- **Pequeno > grande.** Estória pequena é executada, revisada, validada e deployada rápido. Estória grande acumula risco em cada dia que demora.
- **Acabe a estória antes de começar a próxima.** Spread (mexer em N estórias ao mesmo tempo) é receita pra retrabalho.

---

## INVEST — os 6 critérios da estória boa

Toda estória que você manda para sprint deveria atender, na medida do possível:

| Letra | Significa | Pergunta para se cobrar |
|---|---|---|
| **I**ndependent | Independente | Posso executar essa estória sem ter que executar outra primeiro? |
| **N**egotiable | Negociável | A solução exata é discussável até a implementação, ou está prematuramente travada? |
| **V**aluable | Valiosa | Entrega algo observável de valor para o usuário (ou destrava algo que entrega)? |
| **E**stimable | Estimável | Tenho informação suficiente para o agente saber o esforço (S/M/L)? |
| **S**mall | Pequena | Cabe em uma sessão de execução (idealmente até 2h, máximo 4h)? |
| **T**estable | Testável | Os critérios de aceite são observáveis e podem virar testes? |

**INVEST não é checklist mecânica — é vara de medir.** Se 4 dos 6 estão bem e 2 são "mais ou menos", provavelmente OK. Se 3+ falham, **reescreva ou divida** a estória antes de mandar para sprint.

### Detalhamento prático de cada critério

**Independent — independência**
- Sinal de problema: estória X só faz sentido se Y for feita antes, e Y se Z, e Z se W. Sequência longa = você está modelando incremento, não atomicidade.
- Como melhorar: declare dependências explicitamente (`blocked_by`) em vez de assumir ordem. Reordene quando possível.
- Aceitável: dependências simples e claras (a primeira estória cria a tabela; as seguintes usam — natural). Inaceitável: cadeia de 5+.

**Negotiable — negociável**
- Sinal de problema: a estória prescreve **como** fazer ("crie a tabela X com colunas Y, Z, W"). Isso é decisão do Programador, não sua.
- Como melhorar: escreva o **quê** + **por quê**; deixe o **como** explícito como "decisão do Programador".
- Você prescreve: comportamento observável, critérios de aceite, padrões de qualidade.
- Você **não** prescreve: nome de coluna, estrutura de função, biblioteca específica (a menos que tenha decisão arquitetural cobrindo).

**Valuable — valiosa**
- Sinal de problema: estória cuja única justificativa é "destrava a próxima". Isso é estória de **enablement** — válida, mas precisa ser nomeada como tal (`type: enablement`).
- Como melhorar: para estórias de funcionalidade, articule valor concreto para o usuário. Para estórias de enablement, articule **o que destrava** e **por que destravar isso importa**.
- Exemplo bom: "profissional consegue ver o breakdown do match na vaga antes de candidatar-se" → valor claro.
- Exemplo ruim: "implementar componente reutilizável de score" → o quê, sem o por quê.

**Estimable — estimável**
- Sinal de problema: agente não consegue dizer se é S, M ou L porque a estória deixa zonas escuras.
- Como melhorar: zonas escuras precisam virar **dúvidas explícitas** que você responde ou um spike para o Arquiteto.
- Tamanho prático: **S** (até ~30min de trabalho efetivo), **M** (até ~2h), **L** (até ~4h — considere quebrar). Acima de L: divida.

**Small — pequena**
- Sinal de problema: agente precisa criar 5 arquivos novos, mexer em 8 existentes, atravessar 3 módulos.
- Como melhorar: técnicas de splitting (próxima seção).
- **Não confunda "pequena" com "trivial".** Estória pequena pode ter complexidade técnica relevante; ela só precisa ser **focada**.

**Testable — testável**
- Sinal de problema: AC tem palavras como "rapidamente", "bem", "robusto", "amigável".
- Como melhorar: cada palavra subjetiva vira critério observável. "Rápido" → "p95 < 500ms". "Bem" → "passa nos cenários X, Y, Z".
- Se não dá pra testar, não dá pra validar — o épico não fecha.

---

## Como escrever critérios de aceite (AC)

AC são o coração da estória. Eles viram testes. Eles viram o critério de validação no fim do épico.

### Padrão 1 — Given/When/Then

Bom quando o comportamento é **uma transição de estado** ou **uma operação com pré-condições**:

```
CA-1 — Profissional candidata-se a vaga aberta com sucesso.
- Dado que sou profissional ativo, sem turno finalizado pendente de avaliação,
- Quando aciono "Candidatar-me" em uma vaga aberta dentro do meu raio e função,
- Então a candidatura é registrada como pendente e o contratante é notificado.

CA-2 — Candidatura é bloqueada quando há avaliação pendente.
- Dado que sou profissional com turno finalizado ainda não avaliado,
- Quando tento candidatar-me a qualquer vaga,
- Então o sistema bloqueia a ação e me leva para o turno pendente
  com mensagem "Avalie o último turno antes de se candidatar a outra vaga".
```

### Padrão 2 — Declarativo

Bom para comportamentos sem transição clara ou propriedades do sistema:

```
CA-3 — A listagem de vagas no feed do profissional paginada com 20 itens por página.
CA-4 — A senha do usuário nunca aparece em log nem em response da API.
CA-5 — A consulta de match responde em p95 < 800ms com 1k vagas abertas no banco.
```

Use o padrão que mais cabe — **misturar é OK** dentro da mesma estória, desde que cada CA fique claro.

### Hábitos para AC

- **Cada CA é observável.** Posso escrever um teste que verifica? Posso, manualmente, ver isso acontecendo em homologação?
- **Cobre o caminho feliz E pelo menos 2 desvios.** Casos inválidos, exceções, bordas — não delegue para "o programador vai pensar em casos".
- **Não detalhe implementação.** "CA: a tabela `contratantes` tem coluna `cnpj`" é errado — implementação é do Programador.
- **Use linguagem do domínio.** "Vaga", "Turno", "Profissional", "Contratante", "Match" — não "registro", "entidade", "objeto".

---

## Story splitting — quando a estória ficou grande

Estória estimada **L** ou maior deve ser dividida. Técnicas:

### Por workflow (fluxo)

Você tem fluxo do início ao fim. Divida em passos sequenciais.

> **Antes:** Cadastro completo de contratante (formulário com 15 campos do pré-cadastro + completar cadastro com dados sensíveis).
>
> **Depois:**
> - STORY-A: Cadastro mínimo público (nome do responsável, e-mail, telefone, nome do estabelecimento, cidade) — gera registro `pendente_aprovacao`.
> - STORY-B: Aprovação manual no backoffice (admin libera; usuário recebe e-mail e cai no funil welcome).
> - STORY-C: Completar cadastro pós-aprovação parte 1 (CNPJ + endereço completo).
> - STORY-D: Completar cadastro pós-aprovação parte 2 (segmento, cultura, contatos adicionais, logo).
> - STORY-E: Edição posterior do perfil do estabelecimento.

Cada uma é deployável em homologação. Cada uma entrega algo observável.

### Por regra de negócio

Você tem uma feature com regras de validação complexas. Divida pelo nível de validação.

> **Antes:** Aplicar regra de habitualidade (PDR-002) ao aprovar candidatura.
>
> **Depois:**
> - STORY-A: Consultar histórico de alocações do par profissional × estabelecimento na semana corrente.
> - STORY-B: Bloquear aprovação na 3ª alocação semanal quando o profissional é PF.
> - STORY-C: Alertar e exigir override explícito do contratante na 3ª alocação semanal quando o profissional é MEI ou PJ (override anexado ao aceite eletrônico).

### Por variação de dado

Você suporta múltiplos tipos do mesmo dado. Comece com um.

> **Antes:** Notificações ao profissional ao longo do ciclo de turno (push web, e-mail, in-app banner).
>
> **Depois:**
> - STORY-A: Notificação in-app (banner na tela) — caminho principal, funciona com app aberto.
> - STORY-B: Notificação por e-mail — eventos críticos quando o app está fechado.
> - STORY-C: Notificação push web (PWA) — quando a permissão estiver concedida.

### Por interface

Mesma feature, múltiplas formas de invocar. Comece com a principal.

> **Antes:** Gestão de vaga em WebApp, Backoffice (admin) e API (Enterprise futuro).
>
> **Depois:**
> - STORY-A: Gestão de vaga no WebApp (caminho principal — contratante publica, edita, fecha).
> - STORY-B: Intervenção excepcional via Backoffice (admin cancela vaga em nome do contratante quando necessário).
> - STORY-C: API pública para clientes Enterprise (fora do MVP — vira épico próprio depois).

### Por caminho feliz vs erros

Em estória complexa, separe robustez de funcionalidade.

> **Antes:** Cadastro com validação completa + erro amigável + retry em falha de rede + idempotência.
>
> **Depois:**
> - STORY-A: Cadastro caminho feliz + validações principais (CA exclui retry/idempotência).
> - STORY-B: Tratamento de erros + retry + idempotência.

Só faça isso quando a primeira estória ainda entrega valor sozinha — caso contrário, mantenha junto.

---

## Spike: como dimensionar (1 ADR = 1 spike)

Estória de spike (`type: spike`, `target_role: arquiteto`) tem regra de dimensionamento própria, **mais estrita** que estória de implementação. Spike grande costuma esconder múltiplas decisões heterogêneas que deveriam estar separadas.

### Regra dura

> **Uma estória de spike concentra no máximo 1 ADR — ou 2 ADRs fortemente correlatas.**

ADRs **fortemente correlatas** são as que decidem o mesmo subsistema e cuja decisão de uma trava a decisão da outra:

- ✅ "autenticação" e "estratégia de sessão" — uma decide a outra; cabem juntas.
- ✅ "fila de jobs" e "broker de mensagens" — acoplamento direto; cabem juntas.

ADRs **heterogêneas** são as que decidem subsistemas diferentes e podem rodar em paralelo:

- ❌ "stack principal" + "CI/CD" + "observabilidade" + "testes" — quatro subsistemas, quatro spikes.
- ❌ "autenticação" + "e-mail transacional" + "integração Pagar.me" — três áreas, três spikes.

ADRs heterogêneas viram **estórias de spike separadas**, executáveis em paralelo. Concentrá-las viola o princípio "tarefa autocontida em uma sessão" e cria gargalo artificial: tudo que depende da spike espera **todas** as ADRs em vez de só a sua.

### Sinais de spike inchada

- CA-1 e CA-2 pedem ADRs sobre áreas que um humano descreveria como "assuntos diferentes".
- A estimativa saiu "L" mesmo o trabalho sendo "só deliberar".
- O título usa plural genérico: "ADRs de fundação", "ADRs de auth e mais coisas".
- A justificativa para juntar é "tudo é arquitetura mesmo" — não é.

### Quando faz sentido manter junto

Quando as ADRs são tão acopladas que decidir uma sem a outra produz inconsistência (raro). Mesmo nesses casos, considere se não é melhor uma **ADR composta** (uma decisão arquitetural única cobrindo o par) em vez de uma **estória composta** (uma spike concentrando decisões separáveis).

### Spikes e cobertura de testes

Spike não exige cobertura unitária nem E2E — não escreve código de produção. Declare a exceção explicitamente na seção "Padrões de qualidade exigidos" da estória, citando `quality-standards.md`.

---

## Definition of Ready (DoR) — quando a estória pode entrar em sprint

Estória pronta para entrar em sprint atende:

- [ ] **Tem ID e título claro** no formato `STORY-XXX — <título>`.
- [ ] **Frontmatter completo**: epic_id, type, target_role.
- [ ] **Contexto e referências** preenchidos com paths concretos (não "ver na spec").
- [ ] **O quê / por quê** articulados (não apenas "o quê" técnico).
- [ ] **CAs testáveis**: cobertura mínima de feliz + 2 desvios; cada CA observável.
- [ ] **Fora de escopo** explicitado — pelo menos uma menção.
- [ ] **Padrões de qualidade aplicáveis** referenciados (incluindo exceções explícitas se for spike, validation, etc).
- [ ] **Dependências resolvidas** ou explicitamente listadas (`blocked_by`).
- [ ] **ADRs/PDRs aplicáveis** listados — agente não precisa ir caçar.
- [ ] **Liberdade técnica do agente** preservada — você não prescreveu implementação.
- [ ] **Definition of Done** presente.
- [ ] **Protocolo do agente** presente (geralmente por referência).
- [ ] **Tamanho estimado** (S/M/L) preenchido — se L, justifique não dividir.

**Sem DoR, estória entra em sprint, vira `blocked` no meio, atrasa a sprint inteira.** Investir 15 minutos em DoR poupa horas.

---

## Estórias que resistem ao vertical slicing

A regra geral é estória vertical (atravessa o stack). **Mas alguns trabalhos são horizontais por natureza** — forçar verticalidade neles cria atrito artificial:

- **Setup de infraestrutura inicial** (provisionar ambiente, configurar pipeline).
- **Observabilidade transversal** (configurar logger, métricas, tracing — não pertence a um fluxo específico).
- **Sistema de autenticação base** (antes de existir feature que usa).
- **Audit log do sistema** (mecanismo, não consumidor).
- **Refatoração estrutural** (mover módulo, renomear convenção em toda a base).

Para essas, **vertical slicing é exceção justificada**, não regra. O que importa:

- O épico que contém ainda entrega **algo observável no fim** (a primeira feature que **usa** a infra).
- A estória horizontal é nomeada como tal (`type: enablement` no frontmatter).
- A justificativa para horizontalidade está escrita na estória ("Esta estória é horizontal porque setup de pipeline não pertence a fluxo de usuário específico. Destrava STORY-XXX, STORY-YYY.").

**Sinal de abuso**: tudo virou enablement, nada virou feature. Aí o problema é outro — provavelmente o PO está postergando entregar valor.

---

## Anti-padrões clássicos a evitar

### "As a user" vazio

```
❌ Como usuário, eu quero clicar no botão para enviar o formulário.
```

"As a user" sem persona específica e benefício real é só estrutura cosmética. Use quando há persona genuína e valor concreto.

```
✅ Cadastro mínimo de contratante (nome do responsável + nome do estabelecimento + cidade + e-mail) para que o usuário possa enviar pré-cadastro sem precisar preencher CNPJ, endereço completo e demais dados sensíveis antes da aprovação manual da equipe Turni.
```

### Estória técnica disfarçada de user story

```
❌ Como usuário, eu quero que o sistema use Postgres para que os dados persistam.
```

Postgres é decisão arquitetural — ADR. Persistência confiável é NFR — não user story. Use o template apropriado.

### AC ambíguo

```
❌ CA: O sistema deve ser rápido e amigável.
```

"Rápido" e "amigável" não testam. Quantifique:

```
✅ CA: O feed do profissional responde em p95 < 500ms com 1k vagas abertas no banco.
✅ CA: Mensagens de erro citam o campo problemático e sugerem correção.
```

### Estória que prescreve implementação

```
❌ Criar tabela `contratantes` com colunas id (UUID), nome (varchar), cnpj (char 14 unique), criada_em (timestamp).
```

Isso é decisão do Programador (com IDR se virar padrão transversal). A estória diz **o quê**:

```
✅ Persistir cadastro de contratante (nome + CNPJ) com CNPJ único por sistema, com timestamp de criação.
```

### "Tudo ou nada"

```
❌ Cadastro completo de contratante com 15 campos, validações, edição, deleção, listagem, busca.
```

Divida (próxima seção). Estória grande é estória que **não entra em sprint**.

### Critério de aceite que vira teste único enorme

```
❌ CA: O cadastro funciona conforme spec.
```

Cada CA é uma asserção. Múltiplos CAs cobrindo o quê precisa funcionar. Não delegue ambiguidade para o teste.

---

## Resumo operacional

Antes de marcar uma estória como `ready`:

- [ ] Passa nos 6 critérios INVEST (com bom senso, não mecanicamente).
- [ ] CAs cobrem feliz + ao menos 2 desvios.
- [ ] Tamanho está adequado (S ou M; L apenas se justificado).
- [ ] Definition of Ready atendido (lista acima).
- [ ] Se for estória horizontal, justificou por quê.
- [ ] Releu uma vez como se fosse o agente que vai executar — está claro?

Estória bem escrita poupa idas e voltas. Investir 15 minutos a mais na escrita economiza horas no ciclo de execução.
