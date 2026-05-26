# Domínio · Compliance

Decisão de referência: **PDR-002** (habitualidade), **PDR-001** (PF aceito), **PDR-008** (geofencing), **PDR-012** (templates contratuais editáveis no backoffice).

## Princípio

A plataforma não promete blindagem trabalhista — entrega **governança documentada**. Isso significa: regras de habitualidade aplicadas automaticamente, aceite eletrônico timestampado por turno, trilha de auditoria completa e bloqueios automáticos em padrões de risco identificado.

## Habitualidade no mesmo estabelecimento (PDR-002)

**Regra dura**: máximo de **2 alocações por semana corrida (segunda a domingo)** do mesmo profissional no mesmo estabelecimento.

Tratamento na 3ª tentativa:

### Profissional PF

- **Bloqueio duro**. O sistema impede a candidatura ou o aceite.
- Mensagem ao profissional: "Você já tem 2 alocações nesta semana em [Estabelecimento X]. Para cumprir o uso eventual exigido pela legislação, esta candidatura está bloqueada. Outras vagas estão disponíveis no feed."
- Mensagem ao contratante (quando vai aprovar candidatura PF que viola): "Este profissional já realizou 2 turnos com você nesta semana. Como ele é PF, a plataforma bloqueia a alocação para proteger ambos os lados. Considere alocá-lo em outra semana ou escolher outro candidato."

### Profissional MEI ou PJ

- **Alerta + override**. O sistema apresenta aviso visível mas permite continuar.
- Ao aceitar a 3ª candidatura, o contratante precisa **clicar em "Assumo o risco e aceito"** explicitamente. O clique é registrado na trilha de auditoria com timestamp e fica anexado ao aceite eletrônico do turno.
- Mensagem ao contratante: "Este profissional já realizou 2 turnos com você nesta semana. Sinais de habitualidade. Você pode prosseguir, mas isso fica registrado como aceite consciente de risco. Considere se faz sentido continuar."
- Mensagem ao profissional: "Este será seu 3º turno em [Estabelecimento X] nesta semana. O contratante aceitou o risco; você pode aceitar ou recusar a aprovação. Padrão recorrente pode caracterizar vínculo trabalhista."

## Zonas de compliance

Conceitos visuais (UI) baseados na regra dura:

| Zona | Condição | Comportamento |
|---|---|---|
| **Verde** | ≤ 2 alocações/semana neste estabelecimento | Sem alerta. |
| **Amarela** | 2 alocações já realizadas; 3ª tentativa em curso | Alerta visível para ambos. Para PJ: aguardando override. Para PF: bloqueado. |
| **Vermelha** | Padrão sustentado de habitualidade ao longo de várias semanas (3+ semanas consecutivas com 2 alocações cada no mesmo estabelecimento) | Sinal de risco crônico. Plataforma alerta o admin para acompanhamento ativo. Para PF, bloqueio reforçado: sistema bloqueia também a 2ª alocação na semana seguinte até alternância de estabelecimento. |

A condição da zona vermelha é heurística inicial — calibrar com observação real. O importante é o **sinal ao admin** para intervenção humana, não a regra automática.

## Concentração de renda

Sinal complementar (futuro, não MVP completo): se mais de 60% da renda do profissional em 30 dias vem do mesmo contratante, exibir alerta no perfil do profissional ("você está concentrado em [X]; diversificar protege sua relação eventual"). Não bloqueia; informa.

## Aceite eletrônico por turno

A cada criação de turno (aprovação de candidatura), o sistema gera um **documento de aceite eletrônico** com:

- Identificação completa do contratante e do profissional.
- Tipo de pessoa do profissional (PF/MEI/PJ).
- Modelo contratual correspondente:
  - **PF**: contrato de prestação de serviço autônomo eventual.
  - **MEI/PJ**: contrato B2B PJ↔PJ.
- Função, data/hora, valor, taxa Turni, total contratante.
- Cláusula explícita de natureza eventual, ausência de exclusividade, autonomia operacional.
- Timestamp da aprovação.
- IP e fingerprint da sessão de cada aceite.
- Se for 3ª alocação semanal de PJ com override: cláusula adicional registrando o aceite de risco.

Templates específicos (PF e MEI/PJ) são **entidades de dados editáveis pelo admin no backoffice** (PDR-012), com versionamento append-only. Cada aceite eletrônico aponta para a **versão específica do template** que estava vigente no momento da aprovação da candidatura — mudanças posteriores criam nova versão mas **não afetam contratos passados**.

### Estrutura do template no banco

- `Template`: catálogo (`id`, `slug`: `pf_autonomo_eventual` | `mei_pj_b2b`, `nome_amigavel`).
- `TemplateVersao`: cada edição cria nova versão (`id`, `template_id`, `versao` sequencial, `conteudo` com placeholders, `criado_por_admin`, `criado_em`, `ativa` boolean — apenas uma versão por template fica `ativa` de cada vez).
- `AceiteEletronico` (campo do `Turno`): `{ template_versao_id, conteudo_renderizado, dados_renderizados: {...}, timestamp, ip, fingerprint }`. Imutável após criação.

### Placeholders esperados nos templates

Renderizados no momento do aceite a partir dos dados do usuário e do turno:

- `{{contratante.razao_social}}`, `{{contratante.cnpj}}`, `{{contratante.endereco_completo}}`
- `{{profissional.nome}}`, `{{profissional.documento}}` (CPF para PF; CNPJ para MEI/PJ), `{{profissional.endereco_completo}}`
- `{{turno.funcao}}`, `{{turno.data_inicio}}`, `{{turno.data_fim}}`, `{{turno.valor}}`, `{{turno.taxa_turni}}`, `{{turno.total_contratante}}`
- `{{aceite.timestamp}}`, `{{aceite.ip}}`, `{{aceite.fingerprint}}`
- `{{habitualidade.override_aceito}}` (booleano — preenche cláusula adicional quando contratante aceita risco na 3ª alocação semanal de PJ).

### Texto-seed inicial

Versão 1 de cada template é escrita pelo PO com base em referências públicas (cláusulas materiais mínimas: natureza eventual, ausência de exclusividade, autonomia operacional, escopo do serviço, valor, prazo, responsabilidade tributária) e validada pelo Alexandro antes de subir em produção. Validação jurídica externa (advogado trabalhista contratado pela equipe Turni) acontece em qualquer momento posterior — a edição direta no backoffice substitui a necessidade de release.

### Imutabilidade do aceite

Uma vez gerado, o aceite **não pode ser editado nem apagado**. Mesmo se a versão do template for marcada como obsoleta no backoffice, o aceite anexado a um turno continua referenciando a versão original e renderizando exatamente o que foi mostrado e aceito no momento da aprovação. Esta é a garantia jurídica de prova de aceite.

## Trilha de auditoria

Cada turno carrega trilha imutável dos eventos:

- Publicação da vaga (versão original e versões editadas).
- Cada candidatura recebida e seu desfecho.
- Aprovação da candidatura, com aceite eletrônico anexado.
- Geração e validação do PIN de check-in (com `geofencing_ok` + distância).
- Eventos do checklist (item iniciado, item concluído, com timestamp).
- Geração e validação do PIN de check-out.
- Pagamento (captura, Pix enviado).
- Avaliação recíproca.
- Disputa, se aplicável, com justificativa e decisão do admin.
- Cancelamento, se aplicável.

Visível para o admin no backoffice em qualquer momento; visível para contratante e profissional no detalhe do turno (versão simplificada).

## Geofencing (PDR-008)

Detalhado em `domain/turno.md`. Resumo: alerta-e-registra, não bloqueia. Trilha de auditoria carrega evento de check-in com flag de sucesso/falha e distância em metros.

## Lacunas conhecidas

- Limite numérico exato da zona vermelha (3 semanas? 4? com 2 alocações cada?) — calibrar com observação real.
- Política de notificação ao admin quando zona vermelha dispara — automação?
- Tratamento de múltiplos estabelecimentos do mesmo grupo empresarial (ex: rede com 5 unidades — profissional pode trabalhar 2 vezes em cada uma?) — fora do MVP; spike futuro.
- Modelo de relatório fiscal automático para o contratante (especialmente quando contrata PF) — dependência do épico de pagamentos avançado, fora do MVP inicial.
