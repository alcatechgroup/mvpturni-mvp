---
slug: mei_pj_b2b
versao: 1
criado_em: 2026-05-28
criado_por: PO (Alexandro)
rascunho: true
nota_rascunho: "ADR-010 (STORY-013) ainda não aceita — placeholders em formato {{namespace.campo}} (padrão Mustache-like). Revisar após ADR-010 fechada."
---

# Contrato de Prestação de Serviços B2B — Pessoa Jurídica

**Plataforma:** Turni
**Tipo de profissional:** MEI (CNPJ MEI) ou PJ (CNPJ não-MEI)
**Modelo contratual:** Prestação de serviços entre pessoas jurídicas (B2B)

---

## Seção 1 — Termos gerais aplicáveis a todo turno

*Esta seção é renderizada no aceite de adesão (EPIC-001 — completar cadastro) e em todo aceite por turno (EPIC-003+). Apresenta as regras gerais que regem a relação do Profissional com a plataforma e com os contratantes. Pode ser exibida sozinha, sem a Seção 2, quando não há turno vinculado.*

---

### 1. Identificação do Prestador (Profissional)

Nome / Razão Social: **{{profissional.nome}}**
CNPJ: {{profissional.documento}}
Endereço: {{profissional.endereco_completo}}

---

### 2. Natureza da relação

Este documento estabelece os termos gerais que regem a prestação de serviços do Profissional — pessoa jurídica — por meio da plataforma Turni.

A relação estabelecida por este contrato é estritamente **comercial entre pessoas jurídicas (B2B)**, regida pelos arts. 593 a 609 do Código Civil Brasileiro. As partes são empresas autônomas e independentes entre si. A plataforma Turni atua como intermediadora tecnológica.

A relação aqui descrita não preenche os requisitos do art. 3.º da Consolidação das Leis do Trabalho. Não existe vínculo empregatício nem subordinação jurídica ou econômica entre o Profissional e os contratantes atendidos por meio da plataforma. A eventualidade das alocações e a ausência de controle de jornada são condições desta relação.

---

### 3. Ausência de exclusividade

O Profissional é livre para prestar serviços para outros contratantes, inclusive concorrentes dos contratantes com quem trabalha pelo Turni, antes, durante e depois de qualquer relação estabelecida por esta plataforma. Não existe cláusula de exclusividade de qualquer natureza.

---

### 4. Autonomia operacional

O Profissional define sua própria disponibilidade por meio da plataforma Turni, sem obrigação de aceitar qualquer turno específico. O método de execução do trabalho é escolhido pelo próprio Profissional, respeitadas as especificações da função contratada. Quando aplicável à função, o Profissional utiliza seus próprios instrumentos e ferramentas de trabalho.

---

### 5. Responsabilidade tributária

O **Profissional** é responsável pelas suas próprias obrigações tributárias decorrentes desta relação comercial, incluindo:

- Emissão de **nota fiscal de serviços** quando exigida pela legislação ou solicitada pelo Contratante;
- Recolhimento de tributos de sua competência (ISS próprio, PIS/COFINS, CSLL, IRPJ e contribuições previdenciárias) conforme seu regime tributário.

O **Contratante** é responsável pelas suas próprias obrigações tributárias como tomador de serviço, incluindo eventuais retenções na fonte aplicáveis à contratação de pessoa jurídica conforme a legislação vigente e seu próprio regime tributário.

A plataforma Turni não é responsável pelas obrigações tributárias de qualquer das partes. Recomenda-se que ambas consultem seus contadores.

---

### 6. Prazo de pagamento

O pagamento ao Profissional é realizado via **Pix em até 15 (quinze) minutos** após a validação do check-out do turno na plataforma Turni. O valor transferido corresponde integralmente ao valor do turno.

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

### 10. Aceite consciente de risco de habitualidade

*Este bloco é exibido somente quando `{{habitualidade.override_aceito}} = true` — ou seja, quando o Contratante optou por prosseguir com a 3.ª (terceira) ou mais alocação semanal do mesmo Profissional no mesmo estabelecimento, após a plataforma apresentar o alerta de habitualidade conforme PDR-002.*

---

O **Contratante** declara, expressamente e de forma consciente, que:

1. Esta alocação representa a **3.ª (terceira) ou mais** alocação semanal do Profissional no mesmo estabelecimento na semana corrida (segunda a domingo).
2. A plataforma Turni apresentou o alerta de habitualidade e o Contratante optou por prosseguir **voluntariamente**, mediante clique explícito de confirmação de risco.
3. O Contratante está ciente do **risco de caracterização de vínculo empregatício** nos termos do art. 3.º da CLT, em razão da frequência de alocação, e assume esse risco de forma integral e exclusiva, sem responsabilidade da plataforma Turni.

Este aceite de risco é **irrevogável** e registrado com timestamp, IP e identificador de sessão como evidência de ciência e consentimento voluntário.

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

- **CLT, art. 3.º** — definição de empregado. Os termos deste contrato são estruturados para não preencher os requisitos desta definição (ausência de habitualidade, ausência de subordinação jurídica e econômica, ausência de pessoalidade compulsória, ausência de remuneração fixa garantida).
- **Código Civil Brasileiro, arts. 593 a 609** — contrato de prestação de serviços; regime jurídico aplicável às relações B2B eventuais.
- **Lei Complementar n.º 123/2006 e alterações (LC 155/2016)** — Estatuto Nacional da Microempresa e da Empresa de Pequeno Porte; define MEI como pessoa jurídica com CNPJ próprio, faturamento limitado e inscrição obrigatória na Previdência Social. Confirma natureza PJ da relação para fins deste contrato.
- **Medida Provisória n.º 2.200-2/2001** — institui a ICP-Brasil e reconhece a validade de documentos eletrônicos.
- **Lei n.º 14.063/2020** — uso de assinaturas eletrônicas entre privados; reconhece assinatura eletrônica simples como válida para relações entre empresas.
- **PDR-002 e `domain/compliance.md`** — regra de habitualidade: máximo 2 alocações/semana do mesmo profissional no mesmo estabelecimento; 3.ª alocação de MEI/PJ permite override com aceite consciente do contratante (bloqueio duro apenas para PF).

### Decisões de redação

- **Duas seções nomeadas:** Seção 1 renderiza sozinha no aceite de adesão; Seção 2 renderiza com contexto de turno. Motor de renderização (ADR-010) omite Seção 2 quando placeholders de turno/contratante são nulos.
- **Cláusula 10 condicional:** o motor de renderização exibe este bloco somente quando `{{habitualidade.override_aceito}} = true`. Quando false ou ausente, o bloco não aparece no documento final.
- **Cláusula tributária sem alíquotas:** evita desatualização automática do template. Cada parte é orientada a consultar seu contador.
- **Tom do bloco de override:** intencionalmente assertivo ("declara expressamente", "assume esse risco de forma integral e exclusiva") para criar evidência robusta de consentimento informado. Isso é uma decisão de produto consciente, não excesso de juridiquês.
- **Profissional vs. Prestador:** o glossário canônico usa "profissional"; dentro do contrato, o título "Prestador" aparece na identificação (cláusula 1) por ser o termo mais preciso no contexto jurídico B2B — o restante do documento usa "Profissional" conforme o glossário.
- **Vocabulário canônico:** "profissional", "contratante", "turno", "taxa Turni", "estabelecimento".

### Dúvidas registradas para validação jurídica futura

1. **Limite de faturamento MEI:** em 2024/2025 o limite é R$ 81 mil/ano (possível revisão pela LC 194/2022 para R$ 144.900 — confirmar limite vigente em produção). Se o profissional ultrapassar o limite durante o uso da plataforma, o CNPJ MEI pode ser cancelado pela Receita Federal. O template não trata desse risco; avaliar com advogado se deve incluir cláusula de responsabilidade do profissional por manter o CNPJ regular.
2. **Nota fiscal MEI e validade:** MEI pode emitir nota fiscal de serviços; em alguns municípios há exigência de credenciamento prévio. A redação atual diz "quando exigida pela legislação ou solicitada pelo Contratante" — validar se é suficiente ou se deve ser mais assertiva.
3. **ISS — tomador vs. prestador:** em muitos municípios o ISS é retido e recolhido pelo tomador do serviço (Contratante) quando o prestador é de outro município ou quando a atividade está na lista de serviços sujeitos a retenção (LC 116/2003). A cláusula atual é genérica — validar com advogado a redação para cobrir esse caso sem criar obrigação indevida para a plataforma.
4. **Override de habitualidade e eficácia jurídica:** a cláusula 10 registra ciência e consentimento do contratante. A eficácia prática como defesa em ação trabalhista futura não está testada em jurisprudência no contexto de plataformas digitais. Alertar Alexandro explicitamente: o objetivo é documentar o risco assumido, não oferecer blindagem absoluta.
5. **Diferenciação MEI vs. PJ pura:** o template atual trata MEI e PJ da mesma forma (ambos são CNPJ, relação B2B). Se em produção surgirem diferenças de tratamento tributário ou de habitualidade relevantes entre MEI e PJ pura, pode ser necessário criar um terceiro template ou adicionar bloco condicional por subtipo.
6. **Validade da assinatura eletrônica simples em demandas trabalhistas:** confirmar com advogado se a assinatura eletrônica simples (IP + timestamp + fingerprint) é aceita como prova em juízo trabalhista ou se é recomendável migrar para assinatura eletrônica avançada (certificado digital) em versão futura.
