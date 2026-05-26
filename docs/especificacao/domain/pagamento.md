# Domínio · Pagamento

Decisão de referência: **PDR-004** (modelo financeiro), **PDR-010** (refresh Pix fora MVP).

## Modelo

| Fluxo | Lado | Valor |
|---|---|---|
| Profissional **recebe** | Profissional | `valor` (integral, sem desconto) |
| Contratante **paga** | Contratante | `valor + taxa_turni` |
| Plataforma **arrecada** | Turni | `taxa_turni` (15% sobre `valor` no MVP) |

Resumo: **Profissional recebe o que combinou; contratante paga 15% a mais; Turni só toca o dinheiro do contratante**.

## Provedor único

**Pagar.me** é o único PSP no MVP. Toda movimentação financeira passa por ele.

## Ciclo de vida do pagamento (atrelado ao Turno)

1. **Aprovação de candidatura** → cria turno em `confirmado` → **pré-autorização Pagar.me** do `total_contratante` no meio de pagamento do contratante.
2. **Check-in validado** → turno `ativo`. Pagamento ainda **não capturado**; pré-autorização continua segura.
3. **Check-out validado** → turno `finalizado` → **captura Pagar.me** do valor pré-autorizado → **Pix automático** do `valor` para a chave Pix do profissional → **taxa_turni** fica na conta Turni dentro do Pagar.me.
4. **Promessa pública**: Pix em até 15 min após captura.

## Variações de fluxo

### Cancelamento antes do check-in

- Em `cancelado_pro` ou `cancelado_emp`: pré-autorização é **liberada** (não capturada). Contratante não paga, profissional não recebe.

### Disputa

- Em `em_disputa`: pré-autorização permanece bloqueada até resolução.
- Resolução `paga_integral` → captura igual ao fluxo normal.
- Resolução `paga_parcial` → captura ajustada para `valor_revisado + taxa_turni_proporcional`; diferença é liberada.
- Resolução `sem_pagamento` → pré-autorização liberada totalmente; profissional não recebe, contratante não paga.

### No-show (profissional)

- Em `no_show_pro` (sem check-in até X horas após início previsto): pré-autorização liberada. Profissional não recebe. Avaliação do contratante registrada como referência futura para motor de penalidade (PDR-007).

## Refresh / falha de Pix (PDR-010)

- Sistema executa Pix **uma vez** após captura.
- Falha gera alerta no backoffice admin para tratamento manual.
- Não há motor automático de retry no MVP.
- Profissional pode ser comunicado manualmente pela equipe Turni; comunicação automatizada é evolução.

## Visibilidade financeira

### Profissional

- Por turno: vê `valor` (o que recebe) com destaque; vê em letra menor "valor integral · taxa Turni cobrada do contratante".
- Por período (financeiro): vê total recebido por dia, semana, quinzena, mês com gráficos básicos.
- Não vê detalhe da taxa Turni (não é responsabilidade dele).

### Contratante

- Por turno: vê `valor` (o que paga ao profissional) **e** `taxa_turni` **e** `total_contratante` separados.
- Por período (financeiro): vê total pago, separado por componente. Filtros por turno, profissional, função.

### Admin

- Vê tudo. Filtros por contratante, profissional, período, status de pagamento.
- Lista de Pix com falha em destaque na fila operacional.

## Aspectos tributários

### Profissional MEI ou PJ

- Recebe valor integral via Pix sem retenção pela plataforma.
- DAS-MEI ou imposto PJ é responsabilidade do profissional. Plataforma fornece relatório de recebimentos por período.

### Profissional PF (PDR-001)

- Recebe via Pix sem retenção pela plataforma.
- **Responsabilidade tributária do contratante**: a contratação eventual de PF pode acionar retenção de IRRF e contribuição previdenciária (INSS contribuinte individual) na fonte, conforme valor mensal acumulado e legislação vigente. **A plataforma fornece ao contratante relatório com os valores pagos a PF no período**, mas não calcula nem retém os tributos no MVP — isso é evolução pós-MVP com assessoria contábil.

### Contratante

- Recebe nota fiscal Turni mensal pela taxa cobrada (ou via fatura, dependendo do modelo final acordado com Stone/Pagar.me).
- Plataforma fornece relatório de pagamentos a profissionais (separado por tipo de pessoa) para uso contábil próprio.

## Lacunas conhecidas

- Modelo final de retenção tributária quando profissional é PF — spike contábil/jurídico pendente.
- Antecipação de turnos agendados (perk do plano Turnificado) — fluxo de adiantamento ainda não detalhado.
- Split avançado entre múltiplas chaves (caso profissional queira dividir Pix) — fora do MVP.
- Política de devolução em caso de fraude detectada pós-pagamento — fora do MVP.
