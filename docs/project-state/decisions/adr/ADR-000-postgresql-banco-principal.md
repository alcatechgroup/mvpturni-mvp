---
adr_id: ADR-000
slug: postgresql-banco-principal
title: PostgreSQL como banco de dados principal (formalização retroativa)
status: accepted  # proposed | accepted | superseded | rejected | deferred
decided_at: 2026-05-27  # YYYY-MM-DD quando virar accepted
decided_by: arquiteto
approved_by: Alexandro  # ex: "Alexandro" — preenchido na aprovação humana
supersedes: null
superseded_by: null
related_adrs: [ADR-001, ADR-002]
related_pdrs: [PDR-002, PDR-008]
related_epics: [EPIC-000]
created_at: 2026-05-27
updated_at: 2026-05-27
---

# ADR-000 — PostgreSQL como banco de dados principal (formalização retroativa)

> **Natureza desta ADR:** é uma **formalização retroativa**. Não há decisão nova sendo tomada aqui — PostgreSQL **já é** o banco principal do Turni, vigente como princípio arquitetural #3 (`docs/skills/arquiteto/references/architecture-principles.md`) e premissa histórica do projeto. Esta ADR existe para cumprir o princípio não-negociável #5 do PO — *"estado registrado, sempre; sem registro, a decisão não existe"* — capturando contexto, alternativas e trade-offs de uma escolha que, até agora, vivia como folclore técnico. ADR-000 é numerada com `000` propositalmente: marca a decisão de fundação que precede logicamente todas as outras (a stack em ADR-001 já a cita como restrição herdada).

## Contexto

O Turni nasce do protótipo PWA (`docs/prototipo/`) sem código de produção. Linguagem, framework e hospedagem estavam (e em parte ainda estão) em aberto — mas **uma** escolha de fundação foi assumida desde o primeiro dia de documentação técnica e nunca foi reaberta: **PostgreSQL como banco de dados principal**. A convicção está cravada no princípio arquitetural #3 (*"PostgreSQL é nossa primeira opção, sempre"*) e foi tratada como restrição herdada por todas as decisões subsequentes — a SKILL do PO já registra "PostgreSQL já decidido", e ADR-001 (stack) cita "PostgreSQL como banco principal (princípio #3; formalização retroativa em ADR-000/STORY-005)" como restrição dura, escolhendo Eloquent e a fila no driver `database` justamente porque rodam idiomaticamente sobre Postgres.

A lacuna é de **governança documental**, não de decisão: a escolha existe, mas não há um registro que explique *por que* PostgreSQL foi escolhido, *o que* foi (ainda que informalmente) considerado, e *quais consequências* foram aceitas. Sem esse registro, qualquer agente futuro que questione a escolha — "por que não MySQL? por que não um NoSQL?" — não tem referência para responder, e a próxima ADR que assuma PostgreSQL implicitamente herda uma premissa não documentada. O custo de formalizar agora (uma sessão `S`) é minúsculo perto do custo de redescobrir, em 6 meses, a razão de uma decisão de fundação.

As forças funcionais que PostgreSQL precisa sustentar já estão na especificação. Os **RNFs** (`docs/especificacao/non-functional.md`) exigem disponibilidade ≥ 99,5% no WebApp e ≥ 99% no Backoffice, dados sensíveis **criptografados em repouso** (documento, dados bancários, chave Pix, comprovantes), trilha de auditoria de turno **imutável após finalizado** e logs de admin auditáveis. As **regras de negócio** (`docs/especificacao/business-rules.md`) descrevem carga de MVP modesta — dezenas a centenas de estabelecimentos, marketplace em estágio inicial, sem volume de unicórnio (princípio #11, "custo importa"). E vários PDRs aceitos pressionam diretamente o banco: **PDR-002** (habitualidade — consulta histórica por par profissional×estabelecimento/semana sem virar gargalo), **PDR-008** (geofencing — medição de distância profissional↔estabelecimento), **PDR-006** (estado `em_disputa` com captura/estorno parcial), **PDR-005** (gate de avaliação recíproca), todos confortavelmente dentro do que PostgreSQL e suas extensões (PostGIS, índices compostos, `jsonb`) resolvem sem armazenamento adicional.

A decisão é **quase irreversível na prática** (princípio #7): o banco principal carrega o modelo de dados de todo o domínio; trocá-lo depois de o produto existir é reescrita de migração, queries, ORM e operação. Por isso ela merece registro formal — mesmo retroativo — com alternativas e trade-offs honestos.

## Forças (drivers) da decisão

- **F1 — Princípio #3 vigente (Postgres-first):** peso **altíssimo**. Não é uma força entre outras — é uma restrição de identidade técnica do Turni, já ratificada. Esta ADR a formaliza, não a pondera contra as demais.
- **F2 — Capacidade de modelo relacional com integridade transacional (ACID):** peso **alto**. O domínio do Turni é intrinsecamente relacional e financeiro (turno ↔ candidatura ↔ pagamento ↔ disputa), com invariantes que exigem transações fortes — pré-autorização/captura/Pix (PDR-004), estado `em_disputa` (PDR-006), trilha imutável de turno (`non-functional.md`).
- **F3 — "Um banco resolve quase tudo" — minimizar sistemas de dados (princípio #1 e #3):** peso **alto**. Time minúsculo. Cada armazenamento adicional cobra operação, backup, credencial, fonte de incidente. PostgreSQL faz fila (`FOR UPDATE SKIP LOCKED`), `jsonb`, full-text, geo (PostGIS), audit log e pub/sub leve nativamente ou via extensão estável.
- **F4 — Maturidade de ecossistema e suporte de framework opinativo (princípio #4):** peso **médio-alto**. ORM/migrations/fila/observabilidade dos frameworks-alvo precisam ter driver Postgres de primeira classe (Eloquent o tem — ADR-001).
- **F5 — Custo e disponibilidade de PostgreSQL gerenciado (princípio #11):** peso **médio**. Postgres gerenciado é commodity barata em todo provedor sério; lock-in baixo (SQL padrão + dump/restore).
- **F6 — Compatibilidade com TDD/E2E e funcionamento local (princípios #6 e #10):** peso **médio**. Postgres sobe em Docker Compose idêntico a produção; transações por teste e bancos efêmeros são triviais.

> Como esta é uma formalização retroativa, a "matriz comparativa" não pondera opções para **escolher** — a escolha está feita. As forças acima documentam *por que* a escolha se sustenta, e as alternativas abaixo registram *o que foi descartado e por quê*, conforme princípio #12 ("restrições são informação").

## Opções consideradas

> Estas alternativas foram consideradas **informalmente** pela liderança técnica (Alexandro) ao adotar o princípio #3, antes desta formalização. Não houve deliberação documentada na época — recuperamos aqui, honestamente, os trade-offs que sustentaram a preferência por PostgreSQL. Não inventamos uma comparação numérica que não ocorreu.

### Opção A — PostgreSQL como banco principal — **vigente (formalizada aqui)**
- **Resumo:** PostgreSQL como único banco principal do MVP, explorado ao máximo (relacional + `jsonb` + extensões PostGIS/full-text/fila) antes de admitir qualquer armazenamento auxiliar.
- **Como atende aos princípios** (`references/architecture-principles.md`):
  - ✅ **Postgres-first (3):** é a materialização literal do princípio.
  - ✅ **Simplicidade (1):** um único sistema de dados para operar no MVP.
  - ✅ **Monolito (2):** banco compartilhado pelo monolito modular (ADR-002), com schemas/owners por módulo se útil.
  - ✅ **Opinativo (4):** drivers maduros em todos os frameworks-alvo; Eloquent fala Postgres nativamente (ADR-001).
  - ✅ **Funcionamento local (6):** imagem oficial em Docker, paridade dev↔prod.
  - ✅ **TDD/E2E (10):** transações por teste, bancos descartáveis, sem heroísmo.
  - ✅ **Custo (11):** gerenciado barato, lock-in baixo (SQL padrão).
- **Prós concretos:** ACID forte para o domínio financeiro; `jsonb` cobre necessidades de schema flexível sem NoSQL; PostGIS resolve geofencing (PDR-008); índice composto / materialized view resolve habitualidade (PDR-002); fila no banco evita Redis no MVP; comunidade enorme e know-how amplo.
- **Contras concretos:** escalonamento horizontal de escrita exige réplicas/particionamento/sharding mais cedo que um NoSQL distribuído nativo; operação correta (vacuum, índices, tuning) requer skill de Postgres mais cedo que um serviço totalmente gerenciado "sem botões".

### Opção B — MySQL / MariaDB (relacional alternativo)
- **Resumo:** outro RDBMS maduro, igualmente suportado pelos frameworks opinativos, com hospedagem gerenciada ubíqua.
- **Como atende aos princípios:** ✅ relacional/ACID; ✅ barato e gerenciado em todo lugar; ⚠️ ecossistema de extensões **muito** mais pobre que o do Postgres — sem equivalente de primeira classe a PostGIS, a `jsonb` indexável robusto, a `FOR UPDATE SKIP LOCKED` idiomático para fila, a full-text de qualidade comparável.
- **Razão da rejeição:** empata com Postgres no básico relacional, mas **perde no que torna o princípio #3 poderoso** — a capacidade de o banco "fazer muito mais do que se imagina" (geo, JSON, fila, full-text) sem adicionar sistemas. Para um time que quer um banco só, o Postgres entrega mais por menos. Sem vantagem concreta que justificasse preferir MySQL.

### Opção C — Banco NoSQL de documentos (MongoDB) ou gerenciado (DynamoDB)
- **Resumo:** modelar o domínio como documentos, ganhando schema flexível e escalonamento horizontal nativo.
- **Como atende aos princípios:** ⚠️ schema flexível — mas o Postgres cobre isso com `jsonb` indexável sem abrir mão do relacional; ❌ transações multi-documento/multi-tabela mais fracas ou mais caras historicamente — risco direto contra o domínio financeiro do Turni (F2); ❌ joins e integridade referencial não são o forte — e o domínio (turno↔candidatura↔pagamento↔disputa) é fortemente relacional.
- **Razão da rejeição:** o ganho (escala horizontal, flexibilidade de schema) resolve problemas que o Turni **não tem** no MVP (volume modesto — `business-rules.md`) e custa exatamente onde o Turni **mais precisa** (transações ACID sobre dados financeiros e relacionais). Adotar NoSQL como principal violaria princípio #1 (complexidade para dor imaginada) e #3.

### Opção D — Status quo (decisão não registrada)
- **Consequência se mantivermos:** PostgreSQL continua sendo o banco de fato, mas sem ADR. Cada nova ADR que o assume herda uma premissa não documentada; qualquer questionamento futuro ("por que não X?") não tem referência para responder.
- **Custo de adiar:** baixo hoje, **crescente** — quanto mais decisões empilham sobre a premissa implícita, mais caro fica formalizar depois e maior o risco de alguém reabrir a escolha sem contexto. Descartada: o objetivo desta spike é justamente eliminar o status quo.

## Matriz comparativa

**Decisão óbvia — sem matriz ponderada.** PostgreSQL não foi escolhido aqui; ele **é** o princípio arquitetural #3, já vigente e ratificado. A "comparação" honesta cabe em uma frase: entre os relacionais, o Postgres entrega o mesmo ACID que MySQL/MariaDB **mais** um ecossistema de extensões (PostGIS, `jsonb` indexável, fila nativa, full-text) que permite ao time pequeno operar **um único** sistema de dados; e contra NoSQL, vence porque o domínio do Turni é relacional e financeiro, terreno onde transações fortes e integridade referencial importam mais do que escala horizontal — que o volume de MVP (`business-rules.md`) não exige. Forçar uma matriz ponderada para uma decisão já tomada por princípio seria teatro (template `adr.md`: "honestidade > teatro").

## Decisão proposta

> **Optamos pela Opção A — PostgreSQL como banco de dados principal.**

PostgreSQL é o banco de dados principal do Turni e a primeira opção para **toda** necessidade de armazenamento e dados (princípio #3). O modelo de dados de todo o domínio vive no Postgres, sob transações ACID. Necessidades comumente delegadas a sistemas auxiliares são, no MVP, resolvidas **dentro** do Postgres sempre que ele dá conta: fila de jobs via tabela + `SELECT ... FOR UPDATE SKIP LOCKED`; dados semiestruturados via `jsonb` indexável (GIN); medição geográfica para geofencing (PDR-008) via **PostGIS**; consulta de habitualidade (PDR-002) via índice composto e/ou materialized view; full-text via `tsvector`/`tsquery` se necessário; trilha de auditoria via tabela append-only.

**Data efetiva (informal):** PostgreSQL passou a ser o banco principal assumido a partir da fundação documental técnica do projeto — o princípio #3 foi estabelecido junto com os demais princípios arquiteturais, e os PDRs e a SKILL do PO de 2026-05-26 já o tratam como decidido. Não houve um ato formal de decisão anterior a esta ADR; a escolha era uma convicção herdada da liderança técnica. Esta formalização (proposta em 2026-05-27) é o primeiro registro durável dela.

**Adicionar qualquer outro armazenamento** (Redis, ElasticSearch, MongoDB, vector DB dedicado, fila externa, S3 para dados quentes) exige uma **ADR própria** que comece provando, com números, que o Postgres não dá conta — ou que reconheça honestamente um trade-off legítimo de ergonomia/operação/prazo (princípio #3, seção "Postgres-first com bom senso"). Esta ADR **não** decide nenhum armazenamento auxiliar; apenas fixa o principal e o ônus da prova para sair dele.

## Justificativa

A decisão se sustenta porque alinha a força de maior peso (F1 — o próprio princípio #3) com as necessidades reais do domínio. **F2 (ACID relacional):** o coração do Turni é dinheiro e estado de turno — pré-autorização → captura → Pix (PDR-004), `em_disputa` com estorno parcial (PDR-006), trilha imutável (`non-functional.md`) — exatamente onde transações fortes e integridade referencial do Postgres brilham e onde NoSQL cobraria caro. **F3 (um banco só):** para um time minúsculo, cada sistema de dados a mais é imposto operacional; o Postgres absorve fila, geo, JSON e busca sem trazer novos sistemas, mantendo a simplicidade (princípio #1). **F4/F6:** o Eloquent (ADR-001) fala Postgres nativamente, e Postgres sobe local em Docker idêntico a produção, servindo TDD/E2E sem heroísmo. **F5:** Postgres gerenciado é barato e tem lock-in baixo (SQL padrão, dump/restore).

Os trade-offs são reconhecidos, não escondidos: Postgres exige réplicas/particionamento mais cedo que um NoSQL distribuído **se** o volume explodir — mas o volume de MVP não justifica pagar a complexidade do NoSQL hoje (princípio #1: dor imaginada não conta). E operar Postgres bem (índices, vacuum, planos de query) exige skill mais cedo — custo aceito e mitigável com Postgres gerenciado e observabilidade (ADR-008/STORY-004).

## Consequências

### Positivas (o que ganhamos)
- **ACID forte** para todo o domínio financeiro e de estado de turno — base sólida para PDR-004/006/005/007.
- **Um único sistema de dados** no MVP: menos operação, menos backup, menos credencial, menos superfície de incidente (princípios #1, #3, #11).
- **Capacidades de fundação destravadas sem novos sistemas:** transações ACID; `jsonb` indexável para dados semiestruturados; full-text (`tsvector`/GIN) se útil; **PostGIS** disponível para quando o geofencing (PDR-008) virar query de distância; fila no driver `database` (ADR-001); audit log append-only para a trilha imutável (`non-functional.md`).
- **Lock-in baixo e custo previsível:** SQL padrão, dump/restore portável, gerenciado barato em qualquer provedor sério.
- **Fundação citável:** ADRs e PDRs futuros que assumam Postgres passam a ter referência durável.

### Negativas / trade-offs aceitos
- **Escalonamento horizontal de escrita** exige réplicas de leitura, particionamento e eventualmente sharding mais cedo do que um NoSQL distribuído nativo — aceito porque o volume de MVP (`business-rules.md`) não chega perto desse limite, e a saída tem caminho conhecido (réplicas nativas → particionamento → sharding) sem trocar de banco.
- **Operação requer skill de Postgres mais cedo** (tuning, índices, vacuum, planos) — aceito e mitigado por Postgres **gerenciado** (operação delegada ao provedor — detalhe na ADR-004) e por observabilidade de banco (ADR-008).
- **Disciplina de "provar antes de sair do Postgres"** impõe atrito a quem quiser adicionar Redis/Elastic/etc — este atrito é **intencional** (princípio #3), não um defeito.

### Neutras
- O `jsonb` permite ilhas de schema flexível dentro do relacional — útil, mas exige disciplina para não virar "tudo em JSON" e perder a integridade que justifica usar Postgres.
- A escolha de **versão** do PostgreSQL, extensões habilitadas e parâmetros de tuning **não** é decidida aqui — é decisão local do Programador via IDR / da ADR de hospedagem (ADR-004) quando relevante.

### Para o time
- **Impacto em estórias existentes:** dá base formal a STORY-006 (setup local sobe Postgres em Docker), STORY-003/ADR-006 (habitualidade — índice/materialized view sobre Postgres), STORY-002/ADR-004 (hospedagem precisa ofertar Postgres gerenciado a custo razoável), STORY-004/ADR-008 (observabilidade de banco).
- **ADRs/PDRs relacionados que esta decisão limita ou destrava:**
  - **ADR-001 (stack)** já cita ADR-000 como restrição; o ORM/camada de query escolhida (Eloquent) precisa ter driver Postgres maduro — **tem**.
  - **ADR-004 (hospedagem)** fica restrita: o provedor escolhido **precisa** oferecer PostgreSQL gerenciado a custo razoável (princípio #11).
  - **ADR-006 (habitualidade — PDR-002)** assume Postgres: índice composto e/ou materialized view são as ferramentas.
  - **PDR-008 (geofencing)** ganha PostGIS como caminho default para medição de distância.
  - Qualquer armazenamento auxiliar futuro nasce como ADR própria com ônus da prova contra o Postgres.
- **Necessidade de spike de validação:** **não**. Decisão de fundação já vigente e largamente validada pela indústria; não há incerteza técnica a dirimir empiricamente.

## Plano de verificação

- **Como verificar conformidade:**
  - Nenhum outro sistema de dados aparece em `docker-compose`, dependências ou configuração de produção **sem** uma ADR aprovada que justifique a saída do Postgres (verificável em revisão de PR; idealmente um check no setup de STORY-006).
  - Toda ADR futura que proponha armazenamento adicional contém a seção obrigatória "Por que o Postgres não dá conta" com evidência numérica (regra do princípio #3).
- **Sinais de revisão (quando reabrir esta decisão):**
  - **Escala global com consistência fraca:** se um requisito de produto passar a exigir escrita distribuída multi-região com consistência eventual aceitável e o volume tornar réplicas/particionamento Postgres insuficientes **com números medidos** → reabrir para avaliar armazenamento complementar (não necessariamente substituto).
  - **Custo operacional desproporcional:** se o custo do PostgreSQL gerenciado ultrapassar uma fração desproporcional do orçamento de infra (ordem de > ~30%) sem caminho de otimização → reavaliar tier/provedor (ADR-004), não necessariamente o banco.
  - **Gargalo concreto e medido** em uma capacidade hoje atendida pelo Postgres (fila com vazão sustentada acima do que `SKIP LOCKED` aguenta; full-text com ranking sofisticado em volume massivo; geo além do PostGIS) → ADR **específica** para aquele recurso, provando o limite com números — **não** reabre esta ADR, que permanece válida para o papel de banco principal.
- **Spike de validação proposto:** nenhum. Decisão retroativa de fundação, sem incerteza empírica.

---

## Aprovação humana

> Esta seção é o registro formal do aceite. Não preencher sozinho — preencher quando o humano aprovar no chat ou via PR.

- **Status final:** ✅ aceita
- **Aprovado por:** Alexandro
- **Data:** 2026-05-27
- **Forma do aceite:** aprovado em chat (sessão de 2026-05-27)
- **Condicionantes do aceite:** nenhuma.

### Em caso de rejeição
- **Motivo:** ...
- **Próximos passos sugeridos:** ...

### Em caso de superseding
- **Substituída por:** ADR-YYY
- **Razão da substituição:** ...

---

## Histórico

- 2026-05-27 — criada como `proposed` por Arquiteto (STORY-005), formalizando retroativamente o princípio arquitetural #3 (PostgreSQL como banco principal), até então vigente sem ADR. Cumpre o princípio não-negociável #5 do PO ("estado registrado, sempre").
- 2026-05-27 — `accepted` por Alexandro (aprovação em chat).
