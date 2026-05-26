# Screens — inventário de telas

Mapa das telas do produto, organizadas por interface (WebApp + Backoffice) e por papel. Cada entrada referencia o protótipo navegável até que a especificação de tela própria do Designer entre em `docs/project-state/design/screens/`.

> Esta listagem é **inventário**, não screen spec. A spec de tela detalhada (layout, estados, microcopy) é responsabilidade do Designer, escrita por estória.

## WebApp · público (sem login)

| Tela | Rota do protótipo | Função |
|---|---|---|
| Login | `#/login` | Acesso à conta |
| Escolha de cadastro | `#/cadastro` | Escolher PF/MEI/PJ vs. contratante |
| Cadastro de profissional | `#/cadastro/wkr` | Formulário pré-aprovação |
| Cadastro de contratante | `#/cadastro/emp` | Formulário pré-aprovação |

## WebApp · funil pós-aprovação (qualquer papel)

| Tela | Rota do protótipo | Função |
|---|---|---|
| Welcome | `#/welcome` | Boas-vindas, gating para completar cadastro |
| Completar cadastro · profissional | `#/profissional/completar` | Dados sensíveis e bancários |
| Completar cadastro · contratante | `#/contratante/completar` | Identidade da casa, contatos, cultura |

## WebApp · Profissional

| Tela | Rota do protótipo | Função |
|---|---|---|
| Dashboard | `#/profissional` | Resumo, próximas vagas, ações pendentes |
| Feed de vagas | `#/profissional/feed` | Listagem com filtros (todas, minha função, alto match, candidatadas) |
| Detalhe da vaga | `#/profissional/vaga?id=X` | Vaga completa + breakdown do match + candidatar/cancelar |
| Candidaturas | `#/profissional/candidaturas` | Pendentes + aprovadas (viraram turno) |
| Turnos | `#/profissional/turnos` | Em curso + confirmados + histórico |
| Detalhe do turno | `#/profissional/turno?id=X` | PIN, cronômetro, chat, checklist, avaliação |
| Financeiro | `#/profissional/financeiro` | Recebimentos por período |
| Perfil | `#/profissional/perfil` | Edição de dados, depoimentos, score |
| Feedbacks | `#/profissional/feedbacks` | Avaliações recebidas |

## WebApp · Contratante

| Tela | Rota do protótipo | Função |
|---|---|---|
| Dashboard | `#/contratante` | Resumo da casa, vagas e turnos do dia |
| Empresa | `#/contratante/empresa` | RH · cultura, regras, identidade |
| Vagas (lista) | `#/contratante/vagas` | Filtros por status |
| Nova vaga | `#/contratante/vagas/nova` | Formulário de publicação |
| Detalhe da vaga | `#/contratante/vaga?id=X` | Candidatos com match, ações de aprovação, edição |
| Turnos (kanban) | `#/contratante/turnos` | Confirmados / Ativos / Finalizados |
| Detalhe do turno | `#/contratante/turno?id=X` | Validação de PIN, cronômetro, chat, avaliação, disputa |
| Escala da semana | `#/contratante/escala` | Visão semanal compacta |
| Equipe (TURNIficados da casa) | `#/contratante/equipe` | Profissionais recorrentes |
| Financeiro | `#/contratante/financeiro` | Pagamentos por período |
| Atendimento | `#/contratante/atendimento` | Canal com suporte Turni |

## Backoffice · Admin

| Tela | Rota do protótipo | Função MVP (primeira onda) |
|---|---|---|
| Dashboard | `#/admin` | Filas operacionais (aprovações, disputas, alertas) |
| Aprovações | `#/admin/aprovacoes` | Fila de pré-cadastros + ações aprovar/recusar |
| Disputas | (a desenhar) | Fila de turnos em `em_disputa` + decisão |

| Tela | Rota do protótipo | Função (segunda onda) |
|---|---|---|
| Usuários | `#/admin/usuarios` | Busca, edição, suspensão |
| Turnos | `#/admin/turnos` | Visão operacional, intervenção excepcional |
| Vagas | `#/admin/vagas` | Visão operacional |

## Convenções para o Designer

- Cada **estória de UI** (`requires_design: true`) produz um screen spec em `docs/project-state/design/screens/STORY-XXX-<slug>.md`.
- O screen spec cobre **mobile e desktop** (quando aplicável), todos os **estados** (vazio, loading, erro, sucesso, sem permissão), **microcopy** completo, e **identificadores estáveis** para E2E.
- A primeira estória de cada tela referencia esta listagem; estórias subsequentes refinam.
- O **protótipo é referência visual** enquanto não há screen spec próprio.
