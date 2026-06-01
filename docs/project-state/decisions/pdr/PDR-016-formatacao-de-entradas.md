---
pdr_id: PDR-016
slug: formatacao-de-entradas
title: Formatação transversal de entradas (moeda, telefone BR, CEP, CNPJ, CPF) em todas as interfaces
status: accepted
decided_at: 2026-06-01
decided_by: PO (Alexandro / Claude)
supersedes: null
superseded_by: null
related_epics: [EPIC-001]
related_adrs: []
---

# PDR-016 — Formatação transversal de entradas (moeda, telefone BR, CEP, CNPJ, CPF)

## Contexto

O Turni coleta, em várias telas e em ambas as interfaces (WebApp e Backoffice), campos cujo valor digitado pelo usuário precisa ser apresentado num formato canônico brasileiro: valores monetários (vaga, taxa, repasse, Pix), telefones, CEP de endereço, CNPJ do contratante PJ e CPF do profissional/contratante PF. Sem uma regra transversal, cada estória poderia escolher uma formatação diferente — gerando inconsistência visual, divergência entre o que o usuário digita e o que é persistido, e ambiguidade para o desenvolvedor.

A spec não tinha decisão registrada sobre formatação de entrada. As estórias EPIC-001 (cadastro de profissional e contratante) já dependem dela.

## Opções consideradas

### Opção 1 — Deixar cada tela decidir
- Descrição: cada estória resolve a formatação no momento da implementação.
- Prós: nenhuma decisão global a manter.
- Contras: inconsistência entre telas, retrabalho, divergência entre WebApp e Backoffice, ambiguidade para o desenvolvedor.

### Opção 2 — Registrar regra transversal única
- Descrição: a spec fixa, para todo o produto, máscara de exibição, formato canônico em pt-BR e formato persistido (somente dígitos para identificadores; centavos em inteiro para moeda) dos cinco tipos de entrada.
- Prós: zero ambiguidade na implementação; consistência visual; o desenvolvedor consulta um lugar.
- Contras: nenhum relevante — é trabalho de fundação que se faz uma vez.

## Decisão

> **Optamos pela Opção 2.**

A spec passa a registrar, como requisito não-funcional transversal, a formatação canônica de entrada para os cinco tipos abaixo. Vale em **toda interface** com usuário (WebApp e Backoffice) e em **todo o produto**.

| Tipo | Máscara de exibição | Formato canônico | Persistido como |
|---|---|---|---|
| **Moeda (BRL)** | `R$ 1.234,56` (separador de milhar `.`, decimal `,`, 2 casas, símbolo à esquerda com espaço) | pt-BR | inteiro em centavos (`123456`) |
| **Telefone BR** | `(11) 91234-5678` (móvel, 9 dígitos) / `(11) 1234-5678` (fixo, 8 dígitos) | E.164 para integrações: `+5511912345678` | somente dígitos com DDD (`11912345678`); país fixo `BR` no MVP |
| **CEP** | `12345-678` | pt-BR | somente dígitos (`12345678`) |
| **CNPJ** | `12.345.678/0001-90` | pt-BR | somente dígitos (`12345678000190`) |
| **CPF** | `123.456.789-09` | pt-BR | somente dígitos (`12345678909`) |

Regras associadas:

1. **Máscara aplicada ao digitar.** O usuário não precisa digitar separadores; o campo formata em tempo real.
2. **Validação de formato no blur** (perda de foco) com mensagem de erro acessível; validação de dígitos verificadores (CPF/CNPJ) também no blur.
3. **Colagem tolerante.** O campo aceita o valor colado em qualquer formato (com ou sem máscara, com espaços extras) e normaliza para a máscara canônica.
4. **Entrada numérica no mobile.** O teclado do mobile abre em modo numérico para todos os cinco tipos (`inputmode="numeric"` / `TextInputType.number`).
5. **Persistência sem máscara.** O backend recebe e armazena o **formato persistido** da tabela acima; a máscara é responsabilidade exclusiva da camada de UI.
6. **Exibição (read-only) também formatada.** Onde o valor é mostrado fora de um campo de entrada (cards, listas, comprovante, recibo), aplica-se a mesma máscara canônica.
7. **Moeda — entrada por centavos.** O usuário digita o valor pensando em reais; o componente trata internamente como centavos para evitar floats. Não exibir centavos quando inteiro (regra de exibição em comprovante fica a critério do Designer; entrada sempre mostra `R$ 0,00`).
8. **Telefone — somente BR no MVP.** Sem seletor de país. DDI fixo `+55` aplicado na conversão para E.164.

## Justificativa

Estas máscaras são padrão estabelecido em produtos brasileiros e o que o usuário espera. Fixar agora elimina ambiguidade nas estórias do EPIC-001 e remove a possibilidade de divergência entre telas. O custo é baixo: existem pacotes Flutter maduros para máscaras (`mask_text_input_formatter`, `intl` para moeda em pt-BR) — a decisão de implementação fica para o Arquiteto via ADR/IDR, mas o **comportamento esperado** está aqui.

## Consequências

### Positivas
- Consistência visual em todo o produto.
- Desenvolvedor consulta uma única fonte para todos os cinco tipos.
- Persistência uniforme — backend não precisa saber de máscara.
- Validação previsível.

### Negativas / trade-offs aceitos
- Estrangeiros (telefone, CPF) ficam fora do MVP. Aceito — público-alvo é brasileiro (alinhado com `non-functional.md §Internacionalização`).
- Componentes de entrada ganham complexidade (máscara + validação + colagem). Mitigado por pacotes prontos.

### Para o time técnico
- IDR/ADR a fazer: escolha do pacote de máscara (Flutter) e da estratégia de validação (CPF/CNPJ — dígito verificador). A regra de UX está dada; a implementação fica para o Arquiteto.
- Design System (DDR): o componente `input.text` (e suas variantes `input.money`, `input.phone`, `input.cep`, `input.cnpj`, `input.cpf`) entra no catálogo de componentes quando a primeira tela do EPIC-001 o exigir, herdando o comportamento desta PDR.
- Impacto em épicos: EPIC-001 (cadastro) e EPIC-002 (publicar vaga, com valores monetários) consomem esta regra.

## Atualização de especificação

`docs/especificacao/non-functional.md` recebe seção **"Formatação de entradas"** referenciando esta PDR.

## Sinais de revisão

- Se o produto passar a aceitar usuários estrangeiros (telefone internacional, documento alternativo), reabrir para incluir DDI selecionável e tipo de documento.
- Se um componente de máscara causar bug recorrente em validação de colagem, reavaliar a tolerância.
