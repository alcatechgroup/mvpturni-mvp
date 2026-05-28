---
story_id: STORY-015
slug: texto-seed-templates-contratuais
title: Texto-seed dos templates contratuais — PF autônomo eventual v1 + MEI/PJ B2B v1
epic_id: EPIC-001
sprint_id: SPRINT-2026-W24
type: enablement
target_role: po
requires_design: false
status: in_progress
owner_agent: PO (Alexandro / Claude)
created_at: 2026-05-28
updated_at: 2026-05-28
estimated_session_size: M
---

# STORY-015 — Texto-seed dos templates contratuais (PF + MEI/PJ)

> **Para quem vai executar:** esta estória é **enablement de produto** — o PO escreve o conteúdo. Não há agente programador envolvido nesta entrega. Leia inteira antes de começar.

## Contexto (por que esta estória existe)

PDR-012 estabeleceu que o **produto entrega texto-seed inicial dos templates contratuais** (PF autônomo eventual e MEI/PJ B2B), validado pelo Alexandro antes de produção. A partir daí a equipe Turni edita diretamente no backoffice — quando contratar advogado externo, ele edita também por lá, sem release. Esta estória é a **entrega do texto-seed**: dois arquivos Markdown com placeholders no formato decidido em ADR-010 (STORY-013), prontos para serem carregados como `versao = 1` de cada template quando o editor (STORY-020) entrar no ar.

A justificativa para o tipo `enablement` e `target_role: po`: esta é responsabilidade explícita do PO (`epic.md` §"Por que existimos" — "Texto-seed inicial é escrito pelo PO com referências públicas e validado pelo Alexandro antes de produção"). Sem o seed, o editor de templates (STORY-020) abre vazio; o aceite eletrônico (STORY-023/024) não tem o que renderizar; o EPIC-001 não fecha. É horizontal por natureza — não atravessa stack — mas destrava o resto.

- Épico: `docs/project-state/epics/EPIC-001-cadastro-e-aprovacao/epic.md`
- Documentos canônicos a ler ANTES de escrever o texto:
  - `docs/especificacao/domain/compliance.md` §"Aceite eletrônico por turno", §"Estrutura do template no banco", §"Placeholders esperados nos templates", §"Texto-seed inicial"
  - `docs/project-state/decisions/pdr/PDR-001-tipos-de-pessoa-aceitos.md` (consequências para o time técnico — dois templates)
  - `docs/project-state/decisions/pdr/PDR-012-templates-contratuais-editaveis-no-backoffice.md` inteira
  - ADR-010 (STORY-013) — formato de placeholder, motor de renderização (deve estar `accepted` antes desta estória terminar; pode ser iniciada em paralelo, **mas o texto-seed final só pode usar o formato fixado em ADR-010**).
  - `docs/skills/po/SKILL.md` §"Convenções de escrita" (encoding, vocabulário canônico)

## O quê (objetivo desta estória)

Produzir e entregar dois arquivos Markdown:

1. `docs/especificacao/contratos/template-pf-autonomo-eventual-v1.md`
2. `docs/especificacao/contratos/template-mei-pj-b2b-v1.md`

Cada arquivo contém o **texto integral** do template de contrato eletrônico (linguagem juridicamente cuidada mas escrita pelo PO com base em referências públicas — **não** é parecer jurídico definitivo), com **placeholders** no formato decidido em ADR-010 (`{{contratante.razao_social}}`, `{{profissional.documento}}`, etc. — lista completa em `compliance.md` §"Placeholders esperados").

Cobertura material mínima por template (`compliance.md` §"Texto-seed inicial" e PDR-012 §"Justificativa"):
- **Identificação das partes** (placeholders preenchidos no momento do aceite).
- **Natureza da relação**: para PF, **prestação de serviço autônomo eventual** com cláusula explícita de eventualidade, ausência de vínculo trabalhista e ausência de subordinação. Para MEI/PJ, **prestação B2B PJ↔PJ** com cláusula equivalente de autonomia.
- **Ausência de exclusividade**.
- **Autonomia operacional** (profissional define sua agenda, traz seus instrumentos quando aplicável).
- **Escopo do serviço** (referenciado por placeholder do turno: `{{turno.funcao}}`, `{{turno.data_inicio}}`, `{{turno.data_fim}}`).
- **Valor, taxa, total** (`{{turno.valor}}`, `{{turno.taxa_turni}}`, `{{turno.total_contratante}}` — para EPIC-003+; no EPIC-001 essas placeholders ficam vazias/TBD no aceite inicial — o template precisa **degradar bem** quando o turno ainda não existe; ver nota PO abaixo).
- **Responsabilidade tributária**: para PF, retenção de IRRF/INSS na fonte é responsabilidade do contratante (informação, não obrigação de fazer pelo Turni); para MEI/PJ, contratante recebe nota fiscal do prestador.
- **Prazo de pagamento via Pix** (15 min após validação do check-out — futura, mas registrar a promessa).
- **Cláusula adicional de habitualidade override** (apenas no template MEI/PJ): bloco condicional renderizado quando `{{habitualidade.override_aceito}} = true`, registrando o aceite consciente de risco pelo contratante na 3ª alocação semanal (`compliance.md` §"Habitualidade no mesmo estabelecimento").
- **Timestamp, IP, fingerprint do aceite** (placeholders no rodapé do contrato).

**Nota PO importante sobre o aceite na adesão (EPIC-001) vs. aceite por turno (EPIC-003):**
O EPIC-001 gera o aceite no **fim do completar cadastro** (STORY-023, STORY-024), quando o usuário tem documento e endereço completos. Naquele momento **ainda não há turno** — placeholders de turno (`{{turno.funcao}}`, `{{turno.valor}}` etc.) **não se aplicam** ao aceite de adesão. O texto-seed precisa estar estruturado de modo que **o bloco "Termos gerais aplicáveis a todo turno"** seja renderizado sozinho quando contexto de turno está ausente (aceite de adesão); e o **bloco específico do turno** seja preenchido quando o aceite é por turno (EPIC-003+, reutilizando os mesmos templates). Solução sugerida: dividir o template em seções nomeadas (`## Termos gerais` + `## Termos do turno específico`), e o motor de renderização escolhido em ADR-010 omite a segunda seção quando os placeholders dela são `null`. Essa decisão de estrutura é uma orientação do PO ao texto — confirmar com ADR-010 e ajustar formato se necessário.

## Por quê (valor para o usuário)

Valor direto ao **usuário final** (profissional/contratante): o que ele lê e aceita no final do cadastro. Sem texto, não há aceite; sem aceite, não há `ativo`; sem `ativo`, EPIC-001 não fecha. Valor ao **time**: destrava STORY-020 (editor abre com `versao = 1` carregada), STORY-023 e STORY-024 (aceite eletrônico tem o que renderizar). Reduz o tempo entre "advogado validar" e "novo texto em produção" de **semanas (release cycle)** para **minutos (edição no admin)** — esta é a hipótese central de PDR-012.

## Critérios de aceite

- [ ] **CA-1:** Existe `docs/especificacao/contratos/template-pf-autonomo-eventual-v1.md` em Markdown UTF-8 com acentuação portuguesa, com frontmatter mínimo (`slug: pf_autonomo_eventual`, `versao: 1`, `criado_em: <data>`, `criado_por: PO (Alexandro)`).
- [ ] **CA-2:** Existe `docs/especificacao/contratos/template-mei-pj-b2b-v1.md` em Markdown UTF-8 com acentuação portuguesa, com frontmatter mínimo (`slug: mei_pj_b2b`, `versao: 1`, `criado_em: <data>`, `criado_por: PO (Alexandro)`).
- [ ] **CA-3:** Ambos os templates cobrem **toda** a lista de cláusulas materiais mínimas listada em §O quê desta estória (identificação, natureza, ausência de exclusividade, autonomia operacional, escopo, valor/taxa/total quando o turno existe, responsabilidade tributária, prazo de Pix, habitualidade override quando aplicável, timestamp/IP/fingerprint).
- [ ] **CA-4:** Placeholders usam o **formato exato decidido em ADR-010** (STORY-013). Se ADR-010 ainda não estiver `accepted` no momento da escrita, marque rascunho com placeholders em formato `{{namespace.campo}}` (padrão Mustache-like) e revise quando ADR-010 fechar.
- [ ] **CA-5:** Os templates são estruturados em duas seções nomeadas — **Termos gerais aplicáveis a todo turno** (renderiza sozinha no aceite de adesão do EPIC-001) e **Termos do turno específico** (renderiza quando contexto de turno está presente, EPIC-003+). Texto é coerente em ambos os modos.
- [ ] **CA-6:** Texto **legível por não-jurista** — linguagem clara, frases curtas, sem juridiquês desnecessário. Alguém que não é advogado consegue entender o que está aceitando. (Princípio do produto: confiança nasce de clareza.)
- [ ] **CA-7:** Texto usa o **vocabulário canônico do glossário** (`docs/especificacao/glossary.md`): "profissional", "contratante", "turno", "taxa Turni", etc. Sem termos técnicos genéricos.
- [ ] **CA-8:** **Alexandro valida o texto** antes do `status: done`. A validação é registrada como nota na seção "Histórico de validação" de cada arquivo, com data, nome, e (se aplicável) condicionantes ("texto válido para subir em homolog; revisão jurídica externa pendente para produção"). Sem essa validação, a estória **não fecha**.
- [ ] **CA-9:** `index.json` referencia os dois arquivos em um campo apropriado (sugestão: nova chave `spec.contracts: [...]` ou apenas mantém os paths como referência implícita). Frontmatter desta estória atualizado para `status: done`.

## Fora de escopo

- **Validação jurídica externa por advogado trabalhista contratado** — fora desta estória. Acontece em qualquer momento posterior pela equipe Turni; PDR-012 desbloqueia o EPIC-001 sem isso.
- Carregar o texto **no banco** como `versao = 1` de cada template — isso é parte de STORY-020 (editor de templates), via seeder.
- UI de exibição do contrato ao usuário — STORY-023/024.
- Editor para mudar este texto-seed — STORY-020.
- Versões 2+ dos templates — fora do MVP (eventualmente acontece via backoffice, sem release).

## Padrões de qualidade exigidos

Esta estória **não produz código de produção** — produz conteúdo textual. Segue `docs/skills/po/references/quality-standards.md` com as exceções abaixo:

- **Cobertura unitária / E2E:** N/A — não há código.
- **Disciplina aplicável:** rigor redacional (clareza, vocabulário canônico), cobertura material das cláusulas mínimas, validação humana explícita do Alexandro antes de fechar.
- **Encoding UTF-8 com acentuação portuguesa** — `po/SKILL.md` §"Convenções de escrita".
- **Segurança/LGPD:** sem nome real, sem dado real nos exemplos do texto. Placeholders genéricos.

## Dependências

- **Bloqueada por:** STORY-013 (ADR-010) — formato de placeholder e estrutura de seções precisa estar fixado para o texto final usar o padrão certo. Pode-se **começar rascunho** em paralelo; revisão final entra após ADR-010 `accepted`.
- **Bloqueia:** STORY-020 (editor abre com texto-seed carregado), STORY-023 (completar cadastro Profissional + aceite), STORY-024 (completar cadastro Contratante + aceite), STORY-025 (validação).
- **Pré-requisitos:** PO disponível (Alexandro) para escrever e validar.

## Decisões já tomadas (não as reabra)

- **PDR-012** — PO entrega texto-seed inicial; validação jurídica externa não bloqueia EPIC-001.
- **PDR-001** — Dois templates: PF autônomo eventual e MEI/PJ B2B.
- **ADR-010** — formato de placeholder e motor de renderização (consumido).
- **`po/SKILL.md` §Convenções** — encoding, vocabulário canônico.
- **`compliance.md` §Texto-seed inicial** — cláusulas materiais mínimas listadas.

## Liberdade do PO

Você (PO) decide:
- Tom da escrita (formal moderado / acessível — recomendação: acessível com rigor).
- Ordem das cláusulas (recomendação: identificação → natureza → escopo → valor → tributação → prazo → habitualidade override → assinatura).
- Subdivisão em subcláusulas numeradas ou prosa contínua.
- Notas de rodapé com referências públicas que embasaram a redação (referências jurídicas que você usou — opcional, mas ajuda no momento em que advogado externo for revisar).

Você (PO) NÃO decide:
- Formato concreto de placeholder (ADR-010).
- Conteúdo definitivo que substituirá este seed em produção (responsabilidade da equipe Turni com assessoria externa).
- Estrutura de banco que vai armazenar o texto (ADR-010).

## Definição de Pronto (DoD)

- [ ] Os dois arquivos Markdown existem nos paths declarados, em UTF-8 com acentuação, com frontmatter correto.
- [ ] Cláusulas materiais mínimas cobertas em ambos os templates (checklist CA-3).
- [ ] Placeholders no formato de ADR-010.
- [ ] Estrutura em duas seções (Termos gerais + Termos do turno específico) — texto coerente em ambos os modos.
- [ ] Alexandro validou — registrado em "Histórico de validação" de cada arquivo.
- [ ] `index.json` referenciando os paths (se aplicável conforme decisão sobre nova chave) e `status: done` desta estória.
- [ ] "Notas do PO" preenchida (referências públicas consultadas, decisões de redação, dúvidas que ficaram para validação jurídica futura).

## Protocolo (PO executando)

1. Carregue `docs/skills/po/SKILL.md` (você já está nela).
2. Leia `docs/especificacao/domain/compliance.md` e PDR-012 por inteiro.
3. Confirme com a STORY-013 que ADR-010 está `accepted` antes de fechar (placeholders no formato correto).
4. Escreva o rascunho dos dois arquivos.
5. Valide com Alexandro em chat; registre no rodapé de cada arquivo a validação.
6. Atualize `status: done` no frontmatter desta estória e em `index.json`.

## Notas do PO (preenchido durante/após execução)

### Entrada inicial

Sessão iniciada em 2026-05-28. ADR-010 (STORY-013) ainda está `in_progress` — templates redigidos com placeholders no formato `{{namespace.campo}}` (padrão Mustache-like, coerente com compliance.md). Frontmatter marcado com `rascunho: true`; revisão final após ADR-010 aceita.

### Referências públicas consultadas

Ver seção "Notas do PO → Referências públicas consultadas" de cada arquivo de template produzido. Resumo:

- CLT art. 3.º — definição de empregado (o que a relação NÃO é).
- CC arts. 593–609 — contrato de prestação de serviços (pessoa física e B2B).
- Decreto 9.580/2018 (RIR), art. 647 — IRRF na fonte sobre autônomos (PF).
- Lei 8.212/1991, arts. 22 (III) e 28 (I) — INSS sobre serviço de contribuinte individual (PF).
- LC 123/2006 + LC 155/2016 — Estatuto MEI; confirma natureza PJ da relação (MEI/PJ).
- MP 2.200-2/2001 e Lei 14.063/2020 — validade jurídica do aceite eletrônico simples.
- PDR-002 e `domain/compliance.md` — regra de habitualidade e override MEI/PJ.

### Decisões de redação

- **Estrutura em duas seções:** Seção 1 (Termos gerais) renderiza sozinha no aceite de adesão EPIC-001; Seção 2 (Termos do turno específico) renderiza quando contexto de turno presente — motor ADR-010 omite a seção quando placeholders de turno/contratante são nulos.
- **Identificação do contratante na Seção 2:** evita campos em branco visíveis ao profissional no aceite de adesão.
- **Cláusulas tributárias informativas, sem alíquotas:** evita desatualização automática; orienta cada parte a consultar seu contador.
- **Habitualidade override apenas no template MEI/PJ (cláusula 10):** PF tem bloqueio duro (PDR-002); override é exclusivo de MEI/PJ.
- **Tom acessível:** frases curtas, vocabulário canônico do glossário, sem latinismos desnecessários.
- **Retenção do termo "Prestador" na cláusula 1 do MEI/PJ:** mais preciso juridicamente no contexto B2B; restante do documento usa "Profissional" conforme glossário.

### Dúvidas registradas para validação jurídica futura

Consolidadas nos arquivos de template (seção "Notas do PO → Dúvidas registradas"). Resumo dos pontos mais relevantes para o advogado externo:

1. **PF — Simples Nacional:** contratantes no Simples podem ter regras distintas de retenção de IRRF/INSS. A cláusula atual é genérica; validar se é suficiente.
2. **MEI — Limite de faturamento:** confirmar limite vigente em produção (R$ 81 mil ou R$ 144.900); avaliar se o template deve incluir cláusula de responsabilidade do profissional por manter o CNPJ regular.
3. **MEI/PJ — ISS pelo tomador:** LC 116/2003 prevê retenção pelo tomador em determinadas atividades. A cláusula é genérica; validar cobertura.
4. **Override de habitualidade — eficácia jurídica real:** o bloco documenta ciência e consentimento, não oferece blindagem absoluta. Esse ponto precisa ser discutido com advogado antes do primeiro turno em produção.
5. **Assinatura eletrônica simples em ação trabalhista:** confirmar aceitação como prova; avaliar migração para assinatura avançada (certificado digital) em versão futura.

### Validação do Alexandro

(pendente — CA-8 da STORY-015. O texto está pronto para revisão. Alexandro lê os dois arquivos e registra aqui: data, nome, condicionantes — ex.: "texto válido para homolog; revisão jurídica externa antes de produção.")

### Resultado final / evidência

- `docs/especificacao/contratos/template-pf-autonomo-eventual-v1.md`
- `docs/especificacao/contratos/template-mei-pj-b2b-v1.md`
- `index.json` atualizado com `spec.contracts[*]` apontando para os dois arquivos.
- STORY-015 em `status: in_progress`; transição para `done` após CA-8 (validação do Alexandro).
