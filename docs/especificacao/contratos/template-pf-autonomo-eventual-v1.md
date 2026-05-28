---
slug: pf_autonomo_eventual
versao: 1
criado_em: 2026-05-28
criado_por: PO (Alexandro)
rascunho: true
nota_rascunho: "ADR-010 (STORY-013) ainda não aceita — placeholders em formato {{namespace.campo}} (padrão Mustache-like). Revisar após ADR-010 fechada."
---

# Contrato de Prestação de Serviço Autônomo Eventual

**Plataforma:** Turni
**Tipo de profissional:** Pessoa Física (CPF)
**Modelo contratual:** Prestação de serviço autônomo eventual

---

## Seção 1 — Termos gerais aplicáveis a todo turno

*Esta seção é renderizada no aceite de adesão (EPIC-001 — completar cadastro) e em todo aceite por turno (EPIC-003+). Apresenta as regras gerais que regem a relação do Profissional com a plataforma e com os contratantes. Pode ser exibida sozinha, sem a Seção 2, quando não há turno vinculado.*

---

### 1. Identificação do Profissional

Nome completo: **{{profissional.nome}}**
CPF: {{profissional.documento}}
Endereço: {{profissional.endereco_completo}}

---

### 2. Natureza da relação

Este documento estabelece os termos gerais que regem a prestação de serviços do Profissional por meio da plataforma Turni.

Cada turno executado pelo Profissional tem caráter **eventual e não habitual**. O Profissional não está sujeito a ordens permanentes, supervisão contínua ou controle de jornada por parte de qualquer contratante. A plataforma Turni atua como intermediadora tecnológica — não é empregadora do Profissional nem assume o papel de empregador em qualquer relação decorrente deste contrato.

A prestação de serviços aqui descrita não preenche os requisitos do art. 3.º da Consolidação das Leis do Trabalho. Não há vínculo empregatício, nem subordinação jurídica ou econômica, entre o Profissional e os contratantes atendidos por meio da plataforma. A relação é regida pelos arts. 593 a 609 do Código Civil Brasileiro.

---

### 3. Ausência de exclusividade

O Profissional é livre para prestar serviços para outros contratantes, inclusive concorrentes dos contratantes com quem trabalha pelo Turni, antes, durante e depois de qualquer relação estabelecida por esta plataforma. Não existe cláusula de exclusividade de qualquer natureza.

---

### 4. Autonomia operacional

O Profissional define sua própria disponibilidade por meio da plataforma Turni, sem obrigação de aceitar qualquer turno específico. O método de execução do trabalho é escolhido pelo próprio Profissional, respeitadas as especificações da função contratada. Quando aplicável à função, o Profissional utiliza seus próprios instrumentos e ferramentas de trabalho.

---

### 5. Responsabilidade tributária

Por tratar-se de prestação de serviço por **pessoa física autônoma**, o **Contratante de cada turno** é responsável por verificar, calcular e recolher, quando exigido pela legislação vigente:

- **IRRF (Imposto de Renda Retido na Fonte):** conforme art. 647 do Decreto n.º 9.580/2018 (Regulamento do Imposto de Renda), incidente sobre pagamentos a autônomos feitos por pessoa jurídica.
- **INSS — Contribuição Previdenciária:** conforme arts. 22, inciso III, e 28, inciso I, da Lei n.º 8.212/1991, referente ao serviço prestado por contribuinte individual.

Esta cláusula é informativa e não cria obrigação nova para a plataforma Turni, que não retém nem recolhe esses tributos. O Contratante deve consultar seu contador para apurar as obrigações aplicáveis de acordo com seu próprio regime tributário.

---

### 6. Prazo de pagamento

O pagamento ao Profissional é realizado via **Pix em até 15 (quinze) minutos** após a validação do check-out do turno na plataforma Turni. O valor transferido corresponde integralmente ao valor do turno, sem descontos a cargo do Profissional pela plataforma.

---

## Seção 2 — Termos do turno específico

*Esta seção é renderizada somente quando há um turno vinculado a este aceite (EPIC-003+, a partir da aprovação de candidatura). Quando o contexto de turno está ausente — como no aceite de adesão ao completar o cadastro (EPIC-001) — esta seção não é exibida. O motor de renderização (ADR-010) omite esta seção quando os placeholders de turno e contratante são nulos.*

---

### 7. Identificação do Contratante

Razão Social: **{{contratante.razao_social}}**
CNPJ: {{contratante.cnpj}}
Endereço do Estabelecimento: {{contratante.endereco_completo}}

---

### 8. Escopo do serviço

Função contratada: **{{turno.funcao}}**
Data e hora de início: {{turno.data_inicio}}
Data e hora de encerramento: {{turno.data_fim}}

O serviço é prestado no endereço do Estabelecimento identificado na cláusula 7.

---

### 9. Remuneração

| Item | Valor |
|---|---|
| Valor do turno (a ser recebido pelo Profissional) | {{turno.valor}} |
| Taxa Turni (cobrada ao Contratante, não descontada do Profissional) | {{turno.taxa_turni}} |
| **Total pago pelo Contratante** | **{{turno.total_contratante}}** |

O pagamento segue o prazo definido na cláusula 6.

---

## Assinatura eletrônica

Este contrato foi celebrado eletronicamente mediante aceite expresso do Profissional na plataforma Turni.

| Campo | Valor |
|---|---|
| Data e hora do aceite | {{aceite.timestamp}} |
| Endereço IP | {{aceite.ip}} |
| Identificador de sessão (fingerprint) | {{aceite.fingerprint}} |

O aceite eletrônico aqui registrado tem validade jurídica nos termos da Medida Provisória n.º 2.200-2/2001 e da Lei n.º 14.063/2020. O documento é imutável após a geração do aceite.

---

## Histórico de validação

| Data | Validador | Condicionantes |
|---|---|---|
| 2026-05-28 | Alexandro Almeida (PO) | Texto aprovado para homologação. Revisão jurídica externa por advogado trabalhista pendente antes de produção com turnos reais. |

---

## Notas do PO

### Referências públicas consultadas

- **CLT, art. 3.º** — definição de empregado: "toda pessoa física que prestar serviços de natureza não eventual a empregador, sob a dependência deste e mediante salário." Os termos deste contrato são estruturados para não preencher os requisitos desta definição (ausência de habitualidade, pessoalidade contratual opcional, ausência de subordinação e salário fixo).
- **Código Civil Brasileiro, arts. 593 a 609** — contrato de prestação de serviços por pessoa física; regime jurídico supletivo aplicável às relações eventuais sem vínculo empregatício.
- **Decreto n.º 9.580/2018 (Regulamento do Imposto de Renda), art. 647** — IRRF na fonte incidente sobre pagamentos feitos por pessoa jurídica a autônomos; alíquota variável por faixa — não mencionada para evitar desatualização do template.
- **Lei n.º 8.212/1991, art. 22, inciso III, e art. 28, inciso I** — contribuição patronal e do contribuinte individual sobre serviço prestado por autônomo.
- **Medida Provisória n.º 2.200-2/2001** — institui a Infraestrutura de Chaves Públicas Brasileira (ICP-Brasil) e reconhece a validade de documentos eletrônicos.
- **Lei n.º 14.063/2020** — uso de assinaturas eletrônicas em interações com entes públicos e entre particulares; reconhece assinatura eletrônica simples como válida para relações entre privados.

### Decisões de redação

- **Duas seções nomeadas:** Seção 1 renderiza sozinha no aceite de adesão (EPIC-001); Seção 2 renderiza com contexto de turno (EPIC-003+). Motor de renderização (ADR-010) omite Seção 2 quando placeholders de turno/contratante são nulos.
- **Cláusula tributária informativa:** não menciona alíquotas para evitar desatualização automática do template. O Contratante é orientado a consultar seu contador.
- **Sem habitualidade override neste template:** PF tem bloqueio duro na 3.ª alocação semanal (PDR-002); não há aceite de risco possível para PF — a cláusula de override existe apenas no template MEI/PJ.
- **Linguagem acessível:** frases curtas, vocabulário do glossário Turni ("profissional", "contratante", "turno", "taxa Turni"), sem latinismos. Princípio do produto: confiança nasce de clareza.
- **Identificação do contratante na Seção 2:** no aceite de adesão não há contratante específico; mover a identificação do contratante para a Seção 2 evita campos em branco visíveis ao usuário no EPIC-001.

### Dúvidas registradas para validação jurídica futura

1. **Contratantes no Simples Nacional:** empresas optantes pelo Simples têm regras distintas de retenção de IRRF e INSS — em alguns casos, a retenção não se aplica. A cláusula atual é genérica ("quando exigido pela legislação vigente") e remete ao contador do contratante. Validar com advogado se a redação é suficiente ou se deve mencionar explicitamente a exceção do Simples.
2. **INSS do contribuinte individual vs. autônomo:** a Lei 8.212/91 diferencia contribuinte individual de autônomo em alguns contextos. Confirmar com advogado se a referência aos arts. 22 (III) e 28 (I) cobre o caso de forma tecnicamente precisa para o perfil típico de profissional Turni (garçom, bartender, cozinheiro PF).
3. **Contratantes pessoa física:** se algum contratante no Turni for pessoa física (não-empresa), o art. 647 do RIR não se aplica (PF não é agente de retenção de IRRF). Validar se o Turni aceita contratantes PF e, se sim, se a cláusula tributária precisa de versão diferenciada.
4. **Limiar de isenção de IRRF:** pagamentos abaixo da faixa de isenção não geram retenção. O contrato não menciona isso para simplificar — validar se deve.
5. **Validade da assinatura eletrônica simples para contratos de trabalho eventual:** a Lei 14.063/2020 valida a assinatura eletrônica simples para relações entre privados. Confirmar com advogado se há requisito de força probatória adicional (certificado ICP-Brasil) para ações trabalhistas.
