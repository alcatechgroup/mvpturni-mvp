---
pdr_id: PDR-004
slug: modelo-financeiro-taxa-do-contratante
title: Taxa Turni cobrada do contratante; profissional recebe valor integral; Pix em até 15 min
status: accepted
decided_at: 2026-05-26
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: []
related_adrs: []
---

# PDR-004 — Taxa Turni cobrada do contratante; profissional recebe valor integral

## Contexto

O modelo financeiro do Turni precisa ser explícito porque define a percepção de valor de cada lado. O protótipo demonstra um padrão claro: o contratante paga `valor + taxa Turni (15%)`; o profissional recebe **o valor integral**, sem desconto da plataforma. O Pix sai em até 15 minutos após o check-out validado, com pré-autorização no aceite e débito real no check-out, via Pagar.me. Essa é uma escolha de posicionamento — "a plataforma não tira do seu turno" — que diferencia do modelo típico de marketplace que comissiona o prestador.

## Opções consideradas

### Opção 1 — Taxa cobrada do contratante; profissional recebe integral (modelo do protótipo)
- Descrição: Contratante paga `valor + 15%`; profissional recebe `valor` cheio. Taxa Turni de 15% visível e separada na fatura do contratante.
- Prós: Mensagem forte ("você recebe o que combinou"); profissional não sente a plataforma como custo; preço cobrado pelo profissional é o que ele leva; alinhado com a promessa de autonomia.
- Contras: Contratante percebe o custo mais alto; comparado com "comissão sobre prestador", o número parece maior.

### Opção 2 — Taxa partilhada (ex: 10% do contratante + 5% do profissional)
- Descrição: Ambos contribuem com a receita Turni.
- Prós: Visualmente menor para o contratante; receita Turni distribuída.
- Contras: Profissional sente desconto na renda; quebra a mensagem central; protótipo precisaria refazer; complexidade contábil.

### Opção 3 — Taxa cobrada só do profissional (modelo Uber/iFood)
- Descrição: Contratante paga `valor`; profissional recebe `valor - taxa`.
- Prós: Mais conhecido no mercado; aparentemente menor custo para contratante.
- Contras: Quebra completamente a promessa de autonomia; profissional sente como concorrente, não plataforma; rejeita a tese central do produto.

## Decisão

> **Optamos pela Opção 1.**

A taxa Turni é cobrada **apenas do contratante**, em cima do valor do turno. O profissional recebe o **valor integral** que combinou, sem desconto da plataforma. Taxa inicial: **15%** sobre o valor do turno (revisável conforme operação real). Pagamento via **Pix em até 15 minutos** após validação do check-out, via Pagar.me; pré-autorização no aceite, débito real no check-out validado.

## Justificativa

A Opção 1 está no coração da proposta de valor do produto: o turno é do profissional, a plataforma é infraestrutura. Cobrar do profissional contradiria a tese e tiraria diferencial vs. apps genéricos de freelance. A diferença percentual visível para o contratante (Opção 1) é menos importante que a confiança que o profissional tem na plataforma — sem o profissional, não há produto.

## Consequências

### Positivas
- Mensagem central preservada e demonstrável.
- Profissional vê valor cheio no aceite, no perfil e no histórico — sem letra miúda.
- Contratante tem custo previsível e auditável (valor + 15%).
- Modelo idêntico ao do protótipo, sem retrabalho.

### Negativas / trade-offs aceitos
- Contratante percebe 15% como aditivo visível — exige justificação clara na UI (o que ele está pagando, por que vale).
- Receita Turni totalmente concentrada no lado contratante — flutua com volume contratado, não com base de profissionais.
- Cálculo de tributação no relatório fiscal (especialmente quando PF entra com possibilidade de IRRF/INSS) precisa apresentar valor profissional, taxa Turni e total claramente separados.

### Para o time técnico
- ADRs prováveis: integração Pagar.me (pré-autorização e captura em momento distinto); modelo de dados de pagamento que separa valor profissional, taxa Turni e total contratante; rotina de relatório fiscal por período.
- Impacto em épicos: EPIC de pagamento depende fortemente desta decisão; EPIC de aceite eletrônico precisa apresentar a composição financeira com clareza.

## Sinais de revisão

- Se a taxa de 15% se mostrar insuficiente para sustentar a operação (revisão de unit economics), reavaliar percentual — não modelo.
- Se contratantes Enterprise pedirem modelo de comissão diferente (volume → desconto), abrir variação para o plano específico, sem mexer no modelo base.
- Se análise contábil revelar que o modelo cria distorção tributária relevante (especialmente para o lado contratante), reabrir com assessoria.
