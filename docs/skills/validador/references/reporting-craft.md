# Craft do relatório de validação

O `validation/report.md` é o **produto final** do Validador. PO lê, decide o que fazer com o épico, comunica eventualmente para outros stakeholders. Relatório bem escrito poupa idas e voltas; relatório vago gera reuniões para "entender o que você quis dizer".

Esta reference cobre **como escrever o relatório bem**.

---

## A mentalidade

- **Quem lê é o PO** (e possivelmente o Alexandro). Eles precisam **agir** em cima do que você escreveu. Otimize para acionabilidade.
- **Tom factual**, sem retórica. Sem "infelizmente", "lamentavelmente", "infelizmente identificamos". O fato, com evidência. Sem drama.
- **Estrutura previsível.** Quem leu 3 relatórios seus sabe onde achar cada parte do quarto. Mude a estrutura, perde leitura rápida.
- **Concisão sem perder detalhe.** TL;DR no topo para quem tem 30 segundos; apêndices para quem tem 30 minutos. Atenda os dois.

---

## Estrutura padrão (espelha `templates/validation-report.md`)

```markdown
# Relatório de Validação — EPIC-XXX

## TL;DR
## Resumo executivo
## Checklist preenchido (por bloco)
## Fails categorizados por gravidade
## Passes com ressalva
## Limitações da validação
## Apêndice — evidência detalhada
## Histórico
```

Cada seção tem propósito distinto. Não cole tudo em uma — quem lê precisa pular para a seção certa rapidamente.

**Atenção ao que NÃO entra no relatório:**

- **Recomendação ao PO** — não existe. Validador entrega fatos; PO decide o que fazer com eles.
- **Sugestão de estórias de correção** — não. Não nomeie "STORY-XXX-corr", não estime tamanho, não proponha escopo de correção.
- **Próximos passos** — não. "Sugiro corrigir antes de fechar" é planejamento, é do PO.
- **Observações de processo / input para retrospectiva** — não. Gestão de processo é do PO.
- **Linguagem de aconselhamento** — "recomendo", "sugiro", "considere", "vale lembrança", "merece atenção do PO". Todas fora. Substitua por fato neutro.

Se você sente vontade de escrever uma dessas coisas, é sinal de que cruzou a fronteira. Pare, releia o fato observado, descreva o fato.

---

## TL;DR — para quem tem 30 segundos

3 linhas, máximo 5. Inclui **sempre**:

- **Veredito**: APPROVED / REJECTED / APPROVED com pendências.
- **Contagem rápida**: X passes, Y fails (bloqueantes/não-bloqueantes), Z n/a.
- **Resumo factual** dos bloqueantes em uma frase (o que falhou, sem opinar sobre o que fazer).

**Exemplo bom:**

> **Veredito: REJECTED.** 18 passes, 2 fails (1 bloqueante, 1 não-bloqueante), 3 n/a justificados. **Bloqueante**: CA-3 da STORY-007 sem teste cobrindo (função `validar_digitos_verificadores` com 0% de cobertura).

**Exemplo ruim — não use:**

> **Veredito: REJECTED.** 18 passes, 2 fails. **Recomendação**: corrigir o fail bloqueante antes de fechar; não-bloqueante pode virar estória própria.

(Isso é planejamento — sai. PO lê o fato, PO decide.)

**Outro exemplo ruim:**

> Foi feita a validação completa do EPIC-007 que envolveu... [parágrafo de 200 palavras descrevendo o épico inteiro]

TL;DR não é resumo do épico. **É veredito + fato dos bloqueantes**, nada além.

---

## Resumo executivo — para quem tem 2 minutos

1-2 parágrafos. Inclui:

- Contexto curto do épico (para quem não lembra de cabeça).
- **O que foi entregue**, em uma frase.
- **Achados principais** — bem o suficiente para entender, sem entrar em cada item.
- **Conexão com o veredito** — por que aprovou ou reprovou em termos gerais.

**Exemplo:**

> O EPIC-007 entregou o fluxo de candidatura a uma vaga — profissional consegue ver vaga em homologação, candidatar-se e o contratante consegue confirmar o match. Cobertura geral 84%, núcleo 98.5%. Pipeline verde nos últimos 8 commits da branch principal. **Fail bloqueante observado**: CA-3 ("sistema rejeita arquivo > 5MB com mensagem específica") não tem teste automatizado cobrindo — a validação funciona em homologação mas não está sob teste, o que viola padrão do PO de cobertura. **Fail não-bloqueante**: README do módulo de matching não foi atualizado. Restante OK.

Concisão + específico + factual. **Note:** sem "vira estória pequena de correção", sem "achei um fail" (use "fail observado"), sem juízo sobre o que o PO deveria fazer.

---

## Checklist preenchido — para quem precisa de detalhe

Cada bloco do checklist do PO (7 blocos: CAs, cobertura, automação, funcionalidade observável, qualidade transversal, documentação, veredito) aparece com seus itens:

```markdown
### Bloco 1 — Critérios de aceite das estórias

| Item | Status | Evidência |
|---|---|---|
| 1.1 — CA-1 da STORY-001 (cadastro funciona com dados válidos) | ✅ PASS | Teste `test_cadastro_dados_validos` passa. [CI #1234]. Commit `abc123`. |
| 1.2 — CA-2 da STORY-001 (CNPJ inválido retorna mensagem específica) | ✅ PASS | Teste `test_cadastro_cnpj_invalido` passa. [CI #1234]. |
| 1.3 — CA-3 da STORY-007 (rejeita arquivo > 5MB) | ❌ FAIL — bloqueante | Não há teste cobrindo. Função `validar_tamanho_arquivo` com 0% de cobertura. Detalhes no apêndice A.3. |
| ... | ... | ... |
```

**Princípios:**

- **Todos os itens aparecem**, mesmo os `pass` simples. PO precisa saber que foi verificado.
- **Status visual**: `✅ PASS`, `⚠️ PASS com ressalva`, `❌ FAIL — bloqueante`, `❌ FAIL — não-bloqueante`, `🚫 n/a`.
- **Evidência inline**: link, hash, comando — algo verificável.
- **Detalhes longos no apêndice** com referência. Não inflam o checklist.

---

## Fails categorizados por gravidade

Lista dedicada para PO escanear rapidamente:

```markdown
## Fails identificados

### Bloqueantes

> Classificação conforme `verdict-criteria.md` (CA não cumprido, cobertura abaixo do mínimo, pipeline vermelho, funcionalidade inacessível, etc.).

1. **CA-3 da STORY-007 sem teste cobrindo** (Bloco 1.3)
   - **Critério esperado**: CA-3 da STORY-007 — "sistema rejeita arquivo > 5MB com mensagem específica" coberto por teste automatizado.
   - **O que verifiquei**: função `bloquear_terceira_alocacao_pf` em `candidatura/habitualidade.py` com 0% de cobertura no relatório CI #1234. `grep -r "habitualidade" tests/` retorna vazio. Manualmente em homologação a rejeição funciona.
   - **Classificação**: bloqueante por regra `verdict-criteria.md` — CA com funcionalidade observável mas sem teste automatizado conta como fail bloqueante.
   - **Evidência**: apêndice A.3.

### Não-bloqueantes

> Classificação conforme `verdict-criteria.md` (documentação desatualizada em ponto não-crítico, convenção parcial, etc.).

1. **README do módulo `candidatura` desatualizado** (Bloco 6.1)
   - **Critério esperado**: README do módulo reflete mudanças do épico.
   - **O que verifiquei**: README último commit em 2026-03-12; mudanças do épico em commits posteriores não refletidas.
   - **Classificação**: não-bloqueante — documentação desatualizada em ponto não-crítico (`verdict-criteria.md`).
   - **Evidência**: apêndice A.6.
```

**Para cada fail:**

- **Nome curto** no formato consistente.
- **Critério esperado** — citação do que o checklist exigia.
- **O que verifiquei** — descrição factual + evidência inline.
- **Classificação** — bloqueante ou não-bloqueante, com referência à regra de `verdict-criteria.md` que se aplica.
- **Link para evidência detalhada** no apêndice.

**Note bem o que NÃO entra em cada fail:**

- ❌ Sugestão de estória de correção
- ❌ Escopo de testes que a correção deveria cobrir
- ❌ "Estimativa de tamanho" da correção
- ❌ "O PO deveria...", "vira correção...", "vira pendência..."

Isso é planejamento do PO. Validador para no fato + classificação.

---

## Limitações da validação

Substitui a antiga "Recomendação ao PO" — em vez de aconselhar, o Validador relata o que **não conseguiu verificar** e por quê.

```markdown
## Limitações da validação

> O que ficou fora do alcance desta validação. Honestidade sobre cobertura > simulação de completude.

- **Cobertura do módulo X em ambiente integrado**: não foi possível porque o sandbox não tem o connector externo Y configurado. Verificação ficou na cobertura local + smoke manual em homologação.
- **Evidência de E2E para o cenário Z**: cenário existe na spec mas o último run em CI foi há 12 dias (antes do épico). Não há run pós-épico para anexar.
```

**Princípio**: você diz o que viu e o que não viu. Você não diz o que o PO deveria fazer com isso.

**O que NÃO entra aqui (e nem em nenhum outro lugar do relatório):**

- "Recomendo ao PO..."
- "Sugiro abrir estória..."
- "Vira input para retrospectiva..."
- "PO deveria considerar..."
- "Tamanho estimado: S"

Tudo isso é planejamento. Planejamento é do PO. Fim.

---

## Apêndice — evidência detalhada

Para cada fail e para `pass com ressalva` significativo, expanda no apêndice:

```markdown
## Apêndice A — Evidências detalhadas

### A.3 — CA-3 da STORY-007 sem teste (FAIL bloqueante)

**Critério esperado** (CA-3 da estória):
> "Quando profissional PF tenta candidatar-se à 3ª alocação na mesma semana no mesmo estabelecimento, o sistema bloqueia com mensagem 'Você já tem 2 alocações nesta semana em <Estabelecimento> — para cumprir o uso eventual, esta candidatura está bloqueada' e não persiste a candidatura."

**O que verifiquei**:
1. Busca por teste relacionado:
   ```
   $ grep -r "habitualidade\|terceira_alocacao\|bloquear_pf" tests/
   (nenhum resultado)
   ```
2. Cobertura da função `bloquear_terceira_alocacao_pf`:
   ```
   candidatura/habitualidade.py:
   - linha 42: 0% (função `bloquear_terceira_alocacao_pf` declarada)
   - linhas 43-58: 0% (lógica de contagem semanal + bloqueio)
   ```
3. Verificação manual em homologação: criei profissional PF, registrei 2 turnos finalizados na semana corrente no mesmo estabelecimento, tentei candidatar à 3ª vaga do mesmo contratante → vi mensagem correta de bloqueio. Funcionalidade existe mas não está coberta.

**Reprodução**:
- Commit hash em validação: `abc123def`
- Branch: `main`
- Comando: `npm run test:coverage -- candidatura/`

**Impacto**: regressão de regra de compliance (PDR-002) pode acontecer sem detecção — quebra promessa de governança documentada.

```

Apêndice é o lugar para **detalhe extenso da evidência**. Quem quer entender em profundidade vem aqui. **Não inclua "sugestão" no apêndice** — mesmo aqui não cabe planejamento; apenas reprodução, log, screenshot, citação do critério.

---

## Tom: factual, sem retórica

| Evitar | Preferir |
|---|---|
| "Infelizmente identificamos um problema crítico..." | "Fail bloqueante: ..." |
| "O time fez um excelente trabalho em..." | "Pass com evidência forte em..." |
| "Acredito que devemos...", "Recomendo...", "Sugiro..." | (apague — Validador não recomenda nem sugere. Se sente vontade, escreva o fato em vez disso) |
| "Vira estória pequena de correção..." | (apague — escopo de correção é do PO) |
| "Não foi possível verificar..." | "Não verifiquei porque [motivo específico]. Limitação registrada." |
| "Parece que..." | "Verifiquei e..." (com evidência) ou "Não pude verificar; observação parcial:..." |

Você é **régua**. Régua não tem emoção. Régua tem precisão. **Régua não dá conselho.**

---

## Anti-padrões em relatório

**1. Apenas "OK" em PR comment ou chat — sem relatório.**
Validação **sempre** vira `report.md` versionado. Sem arquivo, não é validação — é opinião.

**2. Relatório copia-cola do checklist.**
Você não está repetindo o checklist; está **respondendo** a cada item com evidência específica.

**3. Veredict sem contar fails.**
"Approved" sem TL;DR mostrando 0 fails e contagem confunde — PO precisa saber o que olhou.

**4. Linguagem ambígua.**
"Mais ou menos OK", "essencialmente passa", "provavelmente cumpre". Validação é binária por item; estado intermediário é `pass com ressalva` declarado.

**5. Evidência ausente em `pass`.**
"Pass" sem mostrar evidência é carimbação. Cada `pass` cita evidência inline.

**6. `n/a` sem justificativa.**
Anti-padrão clássico. Sempre prosa específica.

**7. Tom emocional.**
"Lamentavelmente" ou "felizmente" entra em opinião. Você é factual.

**8. Recomendação ou planejamento — em qualquer dose.**
"Sugiro estória nova...", "Decido reprovar e exigir correção em 3 dias", "Vira pendência da próxima sprint", "Recomendo ao PO...". Tudo fora. Validador relata fatos e classificação. Planejar é do PO; decidir é do PO. Se você sente vontade de escrever uma dessas, é sinal de que cruzou a fronteira do papel.

**9. Relatório muito longo.**
20+ páginas de prosa cansa quem lê. Use apêndice para detalhe — corpo principal compacto.

**10. Atualizar `report.md` sem registrar no histórico.**
Se você precisa corrigir/complementar o relatório depois do veredito inicial, adicione no "Histórico" do template — não reescreva silenciosamente.

---

## Releitura antes de submeter

Antes de marcar o relatório como completo:

- [ ] **TL;DR** está no topo, 3-5 linhas, com veredito + contagem + resumo factual dos bloqueantes (sem "próximo passo recomendado").
- [ ] **Resumo executivo** dá contexto em 1-2 parágrafos, factual.
- [ ] **Cada item do checklist** tem status + evidência inline.
- [ ] **Cada `pass` tem evidência verificável** (não só "ok").
- [ ] **Cada `n/a` tem prosa específica** justificando.
- [ ] **Cada `fail` tem gravidade** classificada (bloqueante / não-bloqueante) com referência à regra de `verdict-criteria.md`.
- [ ] **Sem seção "Recomendação ao PO".** Sem "sugestão de estória" em fail nenhum. Sem "próximo passo". Sem "vira retro".
- [ ] **Busca textual** por `recomend`, `sugir`, `sugest`, `próximo passo`, `vira est`, `retrospect` no relatório — qualquer ocorrência é sinal de cruzamento de fronteira, revisar.
- [ ] **Apêndice** expande os fails e ressalvas relevantes com reprodução — sem aconselhar correção.
- [ ] **Tom factual** — releia procurando palavras emocionais e remova.
- [ ] **Cabe em pessoa lendo em ~5 min** o corpo principal (apêndice à parte).

Se uma das checagens acima falha → não submeta ainda. Ajuste.

---

## Resumo operacional

Relatório bem feito tem:

1. **Topo acionável** (TL;DR factual).
2. **Corpo navegável** (checklist + fails classificados + limitações).
3. **Apêndice profundo** (evidência detalhada).
4. **Tom factual** em todo o texto. **Zero linguagem de aconselhamento.**
5. **Releitura final** antes de submeter — incluindo busca textual por palavras de recomendação.

> **Relatório bom não convence — informa. PO faz o resto, inclusive o plano de correção.**
